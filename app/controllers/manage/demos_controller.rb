class Manage::DemosController < ApplicationController
  include Manage::StreamSessionScoped

  def create
    @session.update!(demo: true)
    redirect_to [ :manage, @session ]
  end

  def destroy
    @session.update!(demo: false)
    redirect_to [ :manage, @session ]
  end
end
