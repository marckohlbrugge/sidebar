RubyLLM.configure do |config|
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"].presence ||
                             Rails.application.credentials.anthropic_api_key
end
