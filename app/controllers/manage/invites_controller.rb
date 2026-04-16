class Manage::InvitesController < Manage::BaseController
  before_action :set_invite, only: [ :show, :edit, :update, :destroy ]

  def index
    @invites = Invite.order(created_at: :desc)
  end

  def show
  end

  def new
    @invite = Invite.new(
      max_sessions: 5,
      max_turns_per_session: 50,
      max_llm_calls_per_session: 20
    )
  end

  def create
    @invite = Invite.create!(invite_params)
    redirect_to manage_invite_path(@invite)
  end

  def edit
  end

  def update
    @invite.update!(invite_params)
    redirect_to manage_invite_path(@invite)
  end

  def destroy
    @invite.destroy!
    redirect_to manage_invites_path
  end

  private

  def set_invite
    @invite = Invite.find_by!(code: params[:id])
  end

  def invite_params
    params.expect(invite: [ :label, :max_sessions, :max_turns_per_session, :max_llm_calls_per_session ])
  end
end
