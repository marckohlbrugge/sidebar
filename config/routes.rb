Rails.application.routes.draw do
  manage_jobs_app = MissionControl::Jobs::Engine
  if Rails.env.production?
    manage_username = Rails.application.credentials.dig(:manage, :username) || "admin"
    manage_password = Rails.application.credentials.dig(:manage, :password) || ""

    manage_jobs_app = Rack::Builder.new do
      use Rack::Auth::Basic, "Manage Jobs" do |username, password|
        username_match = ActiveSupport::SecurityUtils.secure_compare(username.to_s, manage_username.to_s)
        password_match = ActiveSupport::SecurityUtils.secure_compare(password.to_s, manage_password.to_s)

        username_match && password_match
      end

      run MissionControl::Jobs::Engine
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"
  get "i/:code", to: "invites#show", as: :invite

  namespace :invited, path: "" do
    resources :stream_sessions, only: [ :new, :create ], path: "sessions"
  end

  resources :stream_sessions, only: [ :show ], path: "sessions" do
    get :ingest, to: "stream_sessions/ingests#create", on: :member
  end

  mount manage_jobs_app, at: "manage/jobs", as: :manage_jobs

  namespace :manage do
    root to: "stream_sessions#index"
    resources :stream_sessions, only: [ :index, :show, :new, :create, :destroy ], path: "sessions" do
      resource :ingest, only: :destroy
    end
    resources :invites do
      resource :revocation, only: [ :create, :destroy ]
    end
  end
end
