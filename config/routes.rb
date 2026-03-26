Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  namespace :admin do
    root "articles#index"
    resources :articles do
      member do
        patch :publish
        patch :unpublish
        get   :story_card
        get   :story_video
      end
    end
    resources :videos do
      member do
        patch :publish
        patch :unpublish
      end
    end
    resources :categories
    resources :tags
    resource :colophon, only: %i[edit update]
    resource :about, only: %i[edit update]
  end

  resources :videos,     only: %i[index show]
  resources :stories,    only: %i[index show]
  resources :tags,       only: %i[index show]
  resources :categories, only: %i[index show]
  resources :authors,    only: %i[show]
  resources :articles,   only: %i[index show]
  get "colophon" => "colophons#show"
  get "about" => "about#index", as: :about
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "stories#index"
end
