class Manage::StreamSessionsController < ApplicationController
  def index
    @sessions = StreamSession.order(created_at: :desc)
  end

  def show
    @session = StreamSession.find(params[:id])
    @turns = @session.turns.ordered.includes(:gate_decision, :comments)
    @events = @session.transcript_events.ordered.last(20)
  end

  def new
    @session = StreamSession.new
  end

  def create
    @session = StreamSession.create!(youtube_url: params[:stream_session][:youtube_url])
    @session.spawn_ingest!
    redirect_to [ :manage, @session ]
  end

  def stop
    session = StreamSession.find(params[:id])
    session.stop_ingest!
    redirect_to [ :manage, session ]
  end

  def toggle_demo
    session = StreamSession.find(params[:id])
    session.update!(demo: !session.demo?)
    redirect_to [ :manage, session ]
  end
end
