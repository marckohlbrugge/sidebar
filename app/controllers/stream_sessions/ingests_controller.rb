class StreamSessions::IngestsController < ActionController::Base
  skip_forgery_protection

  def create
    session = StreamSession.find_by(token: params[:id])
    return render plain: "not found", status: :not_found unless session
    return render plain: "not a microphone session", status: :bad_request unless session.source_microphone?

    unless Faye::WebSocket.websocket?(request.env)
      return render plain: "upgrade required", status: :upgrade_required
    end

    StreamSession::Deepgram.ensure_reactor!
    ws = Faye::WebSocket.new(request.env)
    StreamSession::BrowserIngest.new(session, ws).attach!

    status, headers, body = ws.rack_response
    headers.each { |k, v| response.set_header(k, v) }
    self.response_body = body
    self.status = status
  end
end
