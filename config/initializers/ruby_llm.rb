RubyLLM.configure do |config|
  config.xai_api_key = ENV["XAI_API_KEY"].presence ||
                       Rails.application.credentials.xai_api_key
end
