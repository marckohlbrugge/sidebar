class Manage::IngestsController < ApplicationController
  include Manage::StreamSessionScoped

  def destroy
    @session.stop_ingest!
    redirect_to [ :manage, @session ]
  end
end
