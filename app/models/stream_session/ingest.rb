require "open3"

class StreamSession::Ingest
  def initialize(stream_session)
    @session = stream_session
    @turns = StreamSession::TurnBuilder.new(stream_session)
  end

  def run
    @session.update!(status: "running", started_at: Time.current)
    abort_session!("session has no stream URL") if @session.youtube_url.blank?

    stream_url = resolve_stream_url(@session.youtube_url)

    EM.run do
      ws = StreamSession::Deepgram.open_client
      audio_io = nil
      pump = nil

      ws.on :open do
        log "deepgram connected, starting ffmpeg"
        audio_io = open_audio_pipe(stream_url)
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

  # Sites like X/Twitter serve signed, short-lived HLS URLs that have to be
  # fetched fresh from the machine doing the ingesting (JWTs are IP-pinned).
  # yt-dlp's `-g` prints the direct stream URL; we fall back to the raw input
  # if yt-dlp isn't available or doesn't recognize the site, so pasting a
  # plain .m3u8/Icecast URL still works without a round-trip.
  def resolve_stream_url(url)
    stdout, stderr, status = Open3.capture3(
      "yt-dlp", "-g", "--no-warnings",
      "--extractor-retries", "5",
      "--sleep-requests", "2",
      url
    )
    http_line = stdout.lines.map(&:strip).find { |l| l.start_with?("http") }
    if status.success? && http_line
      log "yt-dlp resolved stream URL"
      http_line
    else
      log "yt-dlp did not resolve (exit=#{status.exitstatus}): #{stderr.lines.last&.strip} — using raw URL"
      url
    end
  rescue Errno::ENOENT
    log "yt-dlp not on PATH — using raw URL"
    url
  end

  def open_audio_pipe(url)
    cmd = %(ffmpeg -hide_banner -nostdin -loglevel fatal \
      -user_agent "Mozilla/5.0" \
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
      EM.schedule { ws.send(StreamSession::Deepgram::CLOSE_MESSAGE) }
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
