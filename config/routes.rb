Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "pages#home"
  resources :stream_sessions, only: [ :show ], path: "sessions"

  namespace :manage do
    root to: "stream_sessions#index"
    resources :stream_sessions, path: "sessions" do
      resource :ingest, only: :destroy
      resource :demo, only: [ :create, :destroy ]
    end
  end
end
