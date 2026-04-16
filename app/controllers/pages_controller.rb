class PagesController < ApplicationController
  def home
    @demos = StreamSession.demos
  end
end
