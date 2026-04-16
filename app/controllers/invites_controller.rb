class InvitesController < ApplicationController
  def show
    invite = Invite.find_by(code: params[:code])
    if invite.nil? || invite.revoked?
      cookies.delete(:invite_id)
      redirect_to root_path, alert: "That invite link isn't valid."
      return
    end

    cookies.signed[:invite_id] = { value: invite.id, httponly: true, same_site: :lax }
    redirect_to new_invited_stream_session_path
  end
end
