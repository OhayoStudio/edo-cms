Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  namespace :admin do
    root "articles#index"
    resources :articles do
      member do
        patch :publish
        patch :unpublish
        patch :patch_field
        get   :preview
        get   :story_card
        get   :story_video
        post  :share_instagram
      end
    end
    resources :videos do
      member do
        patch :publish
        patch :unpublish
      end
      collection do
        get :metadata
      end
    end
    resources :authors
    resources :categories
    resources :tags
    resource :colophon, only: %i[edit update]
    resource :about, only: %i[edit update]
    resource :setting, only: %i[edit update]
  end

  # Public routes are scoped under an optional locale segment. The
  # `(:locale)` parens make it optional so legacy unscoped URLs keep
  # working — they resolve via the default_locale. Add new locales by
  # extending the regex and config.i18n.available_locales.
  scope "(:locale)", locale: /en|ja/ do
    resources :videos,     only: %i[index show]
    resources :stories,    only: %i[index show]
    resources :tags,       only: %i[index show]
    resources :categories, only: %i[index show]
    resources :authors,    only: %i[show]
    resources :articles,   only: %i[index show]
    get "feed" => "feeds#index", as: :feed, defaults: { format: :rss }
    get "colophon" => "colophons#show"
    get "about" => "about#index", as: :about

    # Static markdown pages served by PagesController — slug whitelist
    # lives in PagesController::SLUGS. Add a new page by appending here
    # AND to that whitelist AND dropping the .md files into
    # db/seeds/pages/.
    get "terms"   => "pages#show", defaults: { slug: "terms" },   as: :terms
    get "privacy" => "pages#show", defaults: { slug: "privacy" }, as: :privacy

    # Defines the root path route ("/")
    root "stories#index"
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
end
