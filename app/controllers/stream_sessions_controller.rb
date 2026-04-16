class StreamSessionsController < ApplicationController
  def show
    @session = StreamSession.find(params[:id])
    @turns = @session.timeline_turns
    @autoplay_replay = params[:replay].present?
  end
end
