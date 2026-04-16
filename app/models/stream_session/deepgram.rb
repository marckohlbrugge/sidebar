require "faye/websocket"
require "eventmachine"

module StreamSession::Deepgram
  URL = "wss://api.deepgram.com/v1/listen"

  PARAMS = {
    model: "nova-3",
    encoding: "linear16",
    sample_rate: 16000,
    channels: 1,
    interim_results: true,
    smart_format: true
  }

  def self.open_client
    Faye::WebSocket::Client.new(
      "#{URL}?#{PARAMS.to_query}",
      nil,
      headers: { "Authorization" => "Token #{api_key}" }
    )
  end

  def self.ensure_reactor!
    return if EM.reactor_running?
    Thread.new { EM.run }
    sleep 0.01 until EM.reactor_running?
  end

  def self.api_key
    ENV["DEEPGRAM_API_KEY"].presence || Rails.application.credentials.deepgram_api_key
  end
end
