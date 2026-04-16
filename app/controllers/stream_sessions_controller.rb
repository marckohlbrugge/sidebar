class StreamSessionsController < ApplicationController
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
    redirect_to @session
  end

  def start
    session = StreamSession.find(params[:id])
    session.spawn_ingest!
    redirect_to session
  end

  def stop
    session = StreamSession.find(params[:id])
    session.stop_ingest!
    redirect_to session
  end
end
