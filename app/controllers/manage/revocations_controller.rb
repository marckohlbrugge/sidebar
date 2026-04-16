class Manage::RevocationsController < Manage::BaseController
  before_action :set_invite

  def create
    @invite.update!(revoked_at: Time.current) unless @invite.revoked?
    redirect_to manage_invite_path(@invite)
  end

  def destroy
    @invite.update!(revoked_at: nil)
    redirect_to manage_invite_path(@invite)
  end

  private

  def set_invite
    @invite = Invite.find_by!(code: params[:invite_id])
  end
end
