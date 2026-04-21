#!/usr/bin/env ruby
# Usage: bin/rails runner script/probe_url.rb <tweet-or-stream-url>
#
# Resolves the URL via yt-dlp (if supported), pipes audio through ffmpeg to
# Deepgram, and prints transcripts to stdout. No DB writes, no jobs — just a
# feasibility check for sources like X/Twitter Spaces that need signed,
# short-lived HLS URLs fetched fresh at stream start.

require "faye/websocket"
require "eventmachine"
require "shellwords"
require "json"

source_url = ARGV[0] or abort "Usage: bin/rails runner script/probe_url.rb <url>"

def resolve(url)
  puts "[probe] resolving with yt-dlp..."
  stdout, stderr, status = nil, nil, nil
  require "open3"
  stdout, stderr, status = Open3.capture3(
    "yt-dlp", "-g", "--no-warnings",
    "--extractor-retries", "5",
    "--sleep-requests", "2",
    url
  )
  http_line = stdout.lines.map(&:strip).find { |l| l.start_with?("http") }
  if status.success? && http_line
    puts "[probe] yt-dlp resolved → #{http_line[0, 120]}..."
    http_line
  else
    puts "[probe] yt-dlp failed (exit=#{status.exitstatus}) — using raw URL"
    puts "[probe]   stdout: #{stdout.inspect[0, 300]}"
    puts "[probe]   stderr: #{stderr.inspect[0, 300]}"
    url
  end
rescue Errno::ENOENT
  puts "[probe] yt-dlp not found on PATH — using raw URL"
  url
end

stream_url = resolve(source_url)

EM.run do
  ws = StreamSession::Deepgram.open_client
  audio_io = nil
  pump = nil

  ws.on :open do
    puts "[probe] deepgram open — spawning ffmpeg"
    cmd = %(ffmpeg -hide_banner -nostdin -loglevel fatal \
      -user_agent "Mozilla/5.0" \
      -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 \
      -i #{stream_url.shellescape} \
      -f s16le -acodec pcm_s16le -ac 1 -ar 16000 pipe:1).gsub(/\s+/, " ")
    audio_io = IO.popen(cmd, "rb")

    pump = Thread.new do
      bytes = 0
      while (chunk = audio_io.read(3200))
        bytes += chunk.bytesize
        EM.schedule { ws.send(chunk) }
      end
      puts "[probe] ffmpeg pipe closed after #{bytes} bytes"
      EM.schedule { ws.send(StreamSession::Deepgram::CLOSE_MESSAGE) }
    end
  end

  ws.on :message do |event|
    data = JSON.parse(event.data) rescue nil
    next unless data && data["type"] == "Results"
    alt = data.dig("channel", "alternatives", 0)
    text = alt && alt["transcript"]
    next if text.blank?
    tag = data["is_final"] ? "FINAL" : "interim"
    speech_final = data["speech_final"] ? " [speech_final]" : ""
    puts "[#{tag}#{speech_final}] #{text}"
  end

  ws.on :error do |event|
    puts "[probe] deepgram error: #{event.message}"
  end

  ws.on :close do |event|
    puts "[probe] deepgram closed: code=#{event.code} reason=#{event.reason}"
    audio_io&.close
    pump&.kill
    EM.stop
  end

  trap("INT") { puts "\n[probe] interrupt — closing"; ws.close; EM.stop }
end
