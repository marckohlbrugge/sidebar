arg = ARGV[0] or abort "Usage: bin/rails runner script/ingest.rb <session-id-or-youtube-url>"
session = if arg =~ /\A\d+\z/
  StreamSession.find(arg)
else
  StreamSession.create!(youtube_url: arg)
end
puts "[session=#{session.id}] starting #{session.youtube_url}"
StreamSession::Ingest.new(session).run
