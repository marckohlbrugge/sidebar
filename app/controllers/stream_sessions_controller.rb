class StreamSessionsController < ApplicationController
  def show
    @session = StreamSession.find_by!(token: params[:id])
    @turns = @session.timeline_turns
    @autoplay_replay = params[:replay].present?
  end
end
