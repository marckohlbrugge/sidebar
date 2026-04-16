module Manage::StreamSessionScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_stream_session
  end

  private

  def set_stream_session
    @session = StreamSession.find_by!(token: params[:stream_session_id])
  end
end
