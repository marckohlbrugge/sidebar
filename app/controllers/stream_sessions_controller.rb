class StreamSessionsController < ApplicationController
  def show
    @session = StreamSession.find(params[:id])
    @turns = @session.turns.ordered.includes(:gate_decision, :comments)
    @autoplay_replay = params[:replay].present?
  end
end
