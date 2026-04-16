class StreamSession::BrowserIngest
  def initialize(session, browser_ws)
    @session = session
    @browser = browser_ws
    @turns = StreamSession::TurnBuilder.new(session)
  end

  def attach!
    StreamSession::Deepgram.ensure_reactor!
    EM.schedule { start_deepgram }
  end

  private

  def start_deepgram
    @deepgram = StreamSession::Deepgram.open_client

    @deepgram.on(:open) { mark_running }
    @deepgram.on(:message) do |event|
      @turns.handle(event.data)
      close_for_invite_limit! if @turns.limit_reached?
    end
    @deepgram.on(:close) { cleanup }

    @browser.on(:message) do |event|
      frame = event.data
      EM.schedule { @deepgram&.send(frame) }
    end

    @browser.on(:close) do
      EM.schedule do
        @deepgram&.send({ type: "CloseStream" }.to_json) rescue nil
        # Deepgram finalizes any in-flight utterance and then closes on its own.
      end
    end
  end

  def mark_running
    ActiveRecord::Base.connection_pool.with_connection do
      @session.update!(status: "running", started_at: Time.current) unless @session.running?
    end
  end

  def cleanup
    @turns.flush!
    ActiveRecord::Base.connection_pool.with_connection do
      @session.update!(status: "stopped", stopped_at: Time.current)
    end
    @browser.close rescue nil
    @deepgram = nil
  end

  def close_for_invite_limit!
    return if @closing_for_limit
    @closing_for_limit = true
    EM.schedule { @deepgram&.send({ type: "CloseStream" }.to_json) rescue nil }
  end
end
