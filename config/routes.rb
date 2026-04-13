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
        post  :share_instagram
        patch  :patch_field
        post   :direct_upload_photo_candidate
        delete :destroy_photo_candidate
      end
    end
    resources :videos do
      member do
        patch  :publish
        patch  :unpublish
        post   :ai_enhance_thumbnail
        post   :promote_candidate_thumbnail
        delete :destroy_candidate_thumbnail
      end
      collection do
        get :metadata
      end
    end
    resources :authors
    post "claude/draft", to: "claude#draft", as: :claude_draft
    resources :categories
    resources :tags
    resource :colophon, only: %i[edit update]
    resource :about, only: %i[edit update]
    scope "google_photos", controller: "google_photos" do
      post "open",   as: :google_photos_open
      post "import", as: :google_photos_import
    end
    scope "flickr", controller: "flickr" do
      get  "albums", as: :flickr_albums
      post "import", as: :flickr_import
    end
    get "blob/:signed_id", to: "blobs#show", as: :blob_proxy
  end

  resources :videos,     only: %i[index show]
  resources :stories,    only: %i[index show]
  resources :tags,       only: %i[index show]
  resources :categories, only: %i[index show]
  resources :authors,    only: %i[show]
  resources :articles,   only: %i[index show]
  get "feed" => "feeds#index", as: :feed, defaults: { format: :rss }
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
