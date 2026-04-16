class Manage::StreamSessionsController < Manage::BaseController
  before_action :set_session, only: :show

  def index
    @sessions = StreamSession.order(created_at: :desc)
  end

  def show
    @turns = @session.timeline_turns
    @events = @session.transcript_events.ordered.last(20)
  end

  def new
    @session = StreamSession.new
  end

  def create
    @session = StreamSession.create!(session_params)
    @session.spawn_ingest!
    redirect_to [ :manage, @session ]
  end

  private

  def set_session
    @session = StreamSession.find(params[:id])
  end

  def session_params
    params.expect(stream_session: [ :youtube_url ])
  end
end
