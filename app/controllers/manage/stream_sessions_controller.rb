class Manage::StreamSessionsController < Manage::BaseController
  before_action :set_session, only: [ :show, :edit, :update, :destroy ]

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

  def edit
  end

  def update
    @session.update!(session_params)
    redirect_to [ :manage, @session ]
  end

  def destroy
    @session.stop_ingest! if @session.process_alive?
    @session.destroy!
    redirect_to manage_stream_sessions_path
  end

  private

  def set_session
    @session = StreamSession.find_by!(token: params[:id])
  end

  def session_params
    params.expect(stream_session: [ :youtube_url ])
  end
end
