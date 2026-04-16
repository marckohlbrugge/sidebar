class StreamSession::Ingest
  def initialize(stream_session)
    @session = stream_session
    @turns = StreamSession::TurnBuilder.new(stream_session)
  end

  def run
    @session.update!(status: "running", started_at: Time.current)
    abort_session!("session has no stream URL") if @session.youtube_url.blank?

    EM.run do
      ws = StreamSession::Deepgram.open_client
      audio_io = nil
      pump = nil

      ws.on :open do
        log "deepgram connected, starting ffmpeg"
        audio_io = open_audio_pipe(@session.youtube_url)
        pump = start_pump(ws, audio_io)
      end

      ws.on :message do |event|
        @turns.handle(event.data)
      end

      ws.on :close do |event|
        log "deepgram closed: #{event.code}"
        @turns.flush!
        audio_io&.close
        pump&.kill
        @session.update!(status: "stopped", stopped_at: Time.current)
        EM.stop
      end

      trap("INT") { ws.close; EM.stop }
    end
  end

  private

  def open_audio_pipe(url)
    cmd = %(ffmpeg -hide_banner -nostdin -loglevel fatal \
      -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 \
      -i #{url.shellescape} \
      -f s16le -acodec pcm_s16le -ac 1 -ar 16000 pipe:1).gsub(/\s+/, " ")
    IO.popen(cmd, "rb")
  end

  def start_pump(ws, audio_io)
    Thread.new do
      while (chunk = audio_io.read(3200))
        EM.schedule { ws.send(chunk) }
      end
      EM.schedule { ws.send({ type: "CloseStream" }.to_json) }
    end
  end

  def log(msg)
    Rails.logger.info "[session=#{@session.id}] #{msg}"
    puts "[session=#{@session.id}] #{msg}"
  end

  def abort_session!(reason)
    @session.update!(status: "stopped", stopped_at: Time.current)
    abort "[ingest] #{reason}"
  end
end
