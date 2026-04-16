class Invited::StreamSessionsController < ApplicationController
  before_action :require_invite!

  def new
    @session = StreamSession.new(source_kind: :microphone)
  end

  def create
    if @invite.spent?
      redirect_to new_invited_stream_session_path, alert: "This invite has been fully used."
      return
    end

    @session = StreamSession.create!(source_kind: :microphone, invite: @invite)
    @invite.increment!(:sessions_used)
    redirect_to @session
  end

  private

  def require_invite!
    @invite = Invite.find_by(id: cookies.signed[:invite_id])
    return if @invite && !@invite.revoked?

    cookies.delete(:invite_id)
    redirect_to root_path, alert: "You need an invite link to start a session."
  end
end
