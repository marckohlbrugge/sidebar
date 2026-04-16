class Manage::BaseController < ApplicationController
  http_basic_authenticate_with(
    name: Rails.application.credentials.dig(:manage, :username) || "admin",
    password: Rails.application.credentials.dig(:manage, :password) || "",
    if: -> { Rails.env.production? }
  )
end
