require "faye/websocket"
require "eventmachine"

class StreamSession::Ingest
  DEEPGRAM_URL = "wss://api.deepgram.com/v1/listen"

  def initialize(stream_session)
    @session = stream_session
    @turn_buffer = []
    @turn_started_at = nil
  end

  def run
    @session.update!(status: "running", started_at: Time.current)
    @session.resolve_video_id!
    @session.detect_kind!
    stream_url = resolve_stream_url
    abort_session!("could not resolve stream url") unless stream_url

    EM.run do
      ws = open_websocket
      audio_io = nil
      pump = nil

      ws.on :open do
        log "deepgram connected, starting ffmpeg"
        audio_io = open_audio_pipe(stream_url)
        pump = start_pump(ws, audio_io)
      end

      ws.on :message do |event|
        handle_message(event.data)
      end

      ws.on :close do |event|
        log "deepgram closed: #{event.code}"
        audio_io&.close
        pump&.kill
        @session.update!(status: "stopped", stopped_at: Time.current)
        EM.stop
      end

      trap("INT") { ws.close; EM.stop }
    end
  end

  private

  def resolve_stream_url
    YtDlp.stream_url(@session.youtube_url)
  end

  def open_websocket
    params = {
      model: "nova-3",
      encoding: "linear16",
      sample_rate: 16000,
      channels: 1,
      interim_results: true,
      smart_format: true
    }.to_query
    api_key = ENV["DEEPGRAM_API_KEY"].presence || Rails.application.credentials.deepgram_api_key
    Faye::WebSocket::Client.new(
      "#{DEEPGRAM_URL}?#{params}",
      nil,
      headers: { "Authorization" => "Token #{api_key}" }
    )
  end

  def open_audio_pipe(stream_url)
    # Live: -re paces ffmpeg to realtime.
    # Recorded: skip -re so we transcribe as fast as Deepgram can process.
    pacing = @session.live? ? "-re" : ""
    cmd = %(ffmpeg -hide_banner -nostdin -loglevel fatal \
      -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 #{pacing} \
      -i #{stream_url.shellescape} \
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

  def handle_message(raw)
    data = JSON.parse(raw)
    ActiveRecord::Base.connection_pool.with_connection do
      TranscriptEvent.from_deepgram(@session, data)
      advance_turn(data)
    end
  rescue JSON::ParserError
    nil
  end

  MIN_WORDS_PER_TURN = 8
  MAX_WORDS_PER_TURN = 80

  def advance_turn(data)
    alt = data.dig("channel", "alternatives", 0)
    text = alt&.dig("transcript").to_s
    return if text.empty?

    if data["is_final"]
      @turn_buffer << text
      @turn_started_at ||= Time.current
      @audio_start_ms ||= ((data["start"] || 0) * 1000).to_i
      @audio_end_ms = (((data["start"] || 0) + (data["duration"] || 0)) * 1000).to_i
    end

    return unless @turn_buffer.any?
    close_turn! if should_close?(data)
  end

  def should_close?(data)
    word_count = @turn_buffer.join(" ").split.size
    return true if word_count >= MAX_WORDS_PER_TURN
    data["speech_final"] && word_count >= MIN_WORDS_PER_TURN
  end

  def close_turn!
    @session.turns.create!(
      text: @turn_buffer.join(" "),
      started_at: @turn_started_at,
      ended_at: Time.current,
      finalized_at: Time.current,
      audio_start_ms: @audio_start_ms,
      audio_end_ms: @audio_end_ms
    )
    log "turn closed (#{@audio_start_ms}–#{@audio_end_ms}ms): #{@turn_buffer.join(" ")}"
    @turn_buffer = []
    @turn_started_at = nil
    @audio_start_ms = nil
    @audio_end_ms = nil
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
