class StreamSession::BrowserIngest
  def initialize(session, browser_ws)
    @session = session
    @browser = browser_ws
    @turns = StreamSession::TurnBuilder.new(session)
  end

  def attach!
    log "browser ws attached"
    StreamSession::Deepgram.ensure_reactor!
    EM.schedule { start_deepgram }
  end

  private

  def start_deepgram
    @deepgram = StreamSession::Deepgram.open_client

    @deepgram.on(:open) { log "deepgram connected"; mark_running }
    @deepgram.on(:error) { |event| log "deepgram error: #{event.message}" }
    @deepgram.on(:message) do |event|
      @turns.handle(event.data)
      close_for_invite_limit! if @turns.limit_reached?
    end
    @deepgram.on(:close) do |event|
      log "deepgram closed code=#{event.code} reason=#{event.reason.inspect}"
      cleanup
    end

    @browser.on(:message) do |event|
      frame = event.data
      EM.schedule { @deepgram&.send(frame) }
    end

    @browser.on(:close) do |event|
      log "browser ws closed code=#{event.code} reason=#{event.reason.inspect}"
      EM.schedule do
        @deepgram&.send(StreamSession::Deepgram::CLOSE_MESSAGE) rescue nil
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
    EM.schedule { @deepgram&.send(StreamSession::Deepgram::CLOSE_MESSAGE) rescue nil }
  end

  def log(msg)
    Rails.logger.info "[browser_ingest session=#{@session.id}] #{msg}"
  end
end
