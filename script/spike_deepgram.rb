require "faye/websocket"
require "eventmachine"
require "json"

url = ARGV[0] or abort "Usage: bin/rails runner script/spike_deepgram.rb <youtube-url>"
api_key = ENV["DEEPGRAM_API_KEY"].presence || Rails.application.credentials.deepgram_api_key
abort "Missing DEEPGRAM_API_KEY" unless api_key

ws_url = "wss://api.deepgram.com/v1/listen?" + {
  model: "nova-3",
  encoding: "linear16",
  sample_rate: 16000,
  channels: 1,
  interim_results: true,
  smart_format: true
}.to_query

EM.run do
  ws = Faye::WebSocket::Client.new(ws_url, nil, headers: { "Authorization" => "Token #{api_key}" })
  audio_io = nil
  pump_thread = nil

  ws.on :open do
    puts "[deepgram] resolving stream url..."
    stream_url = `yt-dlp -f "ba*/b" -g #{url.shellescape} 2>/dev/null`.strip.lines.first&.strip
    abort "[yt-dlp] could not resolve stream url" unless stream_url && !stream_url.empty?
    puts "[deepgram] connected, starting ffmpeg..."
    cmd = %(ffmpeg -hide_banner -loglevel fatal -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 -re -i #{stream_url.shellescape} -f s16le -acodec pcm_s16le -ac 1 -ar 16000 pipe:1)
    audio_io = IO.popen(cmd, "rb")

    pump_thread = Thread.new do
      while (chunk = audio_io.read(3200))
        EM.schedule { ws.send(chunk) }
      end
      EM.schedule { ws.send({ type: "CloseStream" }.to_json) }
    end
  end

  ws.on :message do |event|
    data = JSON.parse(event.data) rescue next
    next unless data["channel"]
    transcript = data.dig("channel", "alternatives", 0, "transcript").to_s
    next if transcript.empty?
    tag = if data["speech_final"] then "SPEECH_FINAL"
    elsif data["is_final"] then "final       "
    else "interim     "
    end
    puts "[#{tag}] #{transcript}"
  end

  ws.on :close do |event|
    puts "[deepgram] closed: #{event.code} #{event.reason}"
    audio_io&.close
    pump_thread&.kill
    EM.stop
  end

  trap("INT") { ws.close; EM.stop }
end
