Rails.application.routes.draw do
  # temporary direct routes to images for migration audit
  resources :attachments, only: [ :show ]
  resources :media_files, only: [ :show ]
  # namespace :assets do
  #   resources :primary_assets, only: [ :show ]
  #   resources :gallery_assets, only: [ :show ]
  # end
  resources :primary_assets
  resources :rich_text_assets

  namespace :images do
    resources :primary_images, only: [ :show ]
    resources :gallery_images, only: [ :show ]
    resources :rich_texts, only: [ :show ]
  end
  resources :images, only: [ :show ]

  # mount Ckeditor::Engine, at: '/admin/ckeditor', as: 'ckeditor'
  apipie
  authenticate :user, ->(user) { user.super_user? } do
    mount Blazer::Engine, at: "blazer"
  end
  devise_for :users,
             controllers: { registrations: "registrations",
                            confirmations: "confirmations",
                            passwords: "passwords" }
  devise_scope :user do
    get "/confirm/:confirmation_token", to: "confirmations#show", as: :confirm
  end
  get "users/change_password", to: "users#change_password", as: "change_password"
  post "users/update_password", to: "users#update_password", as: "update_password"
  get "welcome/:welcome_instructions_token", to: "welcome#show", as: "user_welcome"
  patch "welcome/:welcome_instructions_token", to: "welcome#update", as: "user_welcome_update"
  resources :users, only: [ :new, :index, :show, :edit, :update, :create, :destroy ] do
    collection do
      get :check_duplicates
    end
    member do
      get :generate_person
      post :send_reset_password_instructions
      post :send_welcome_instructions
      post :toggle_lock_status
      post :confirm_email
    end
  end

  post "workshop_logs/validate_new", to: "workshop_logs#validate_new"

  get "contact_us", to: "contact_us#index"
  post "contact_us", to: "contact_us#create"

  get "taggings", to: "taggings#index", as: "taggings"
  get "taggings/matrix", to: "taggings#matrix", as: "taggings_matrix"
  get "tags", to: "tags#index", as: "tags"
  get "tags/sectors", to: "tags#sectors", as: "tags_sectors"
  get "tags/categories", to: "tags#categories", as: "tags_categories"

  get "image_migration_audit", to: "image_migration_audit#index"

  namespace :admin do
    get "/",                         to: "home#index" # admin home page
    get "activities/events",         to: "ahoy_activities#index", as: "activities_events"
    get "activities/visits",         to: "ahoy_activities#visits", as: "activities_visits"
    get "activities/charts",         to: "ahoy_activities#charts", as: "activities_charts"
    get "activities/counts",         to: "analytics#index", as: "activities_counts"
    post "activities/counts/print",  to: "analytics#print", as: "analytics_print"
  end

  resources :banners
  resources :bookmarks do
    post :search
    collection do
      get :tally
      get :personal
    end
  end
  resources :categories do
    collection do
      get :dedupe_index
      get :dedupe_preview
      post :dedupe_execute
      patch :dedupe_update_keep
    end
  end
  resources :community_news
  resources :event_registrations
  resources :events do
    resource :registrations, only: %i[ create destroy ], module: :events, as: :registrant_registration
  end
  resources :people do
    collection do
      get :check_duplicates
    end
  end
  resources :faqs
  resources :notifications, only: [ :index, :show ] do
    member do
      post :resend
    end
  end
  resources :organizations
  resources :organization_statuses
  resources :organization_people
  resources :quotes

  resources :monthly_reports
  get "reports/:id/edit_story", to: "reports#edit_story", as: "reports_edit_story"
  put "reports/update_story/:id", to: "reports#update_story", as: "reports_update_story"
  post "reports/share_story", to: "reports#create_story", as: "create_story"
  get "reports/share_story", to: "reports#share_story"

  get "reports/monthly", to: "monthly_reports#monthly"
  get "reports/monthly_select_type", to: "monthly_reports#monthly_select_type"
  get "monthly_reports", to: "monthly_reports#monthly"

  get "reports/annual", to: "reports#annual"
  resources :reports

  resources :resources do
    get :download
    collection do
      post :search
    end
  end
  resources :sectors do
    collection do
      get :dedupe_index
      get :dedupe_preview
      post :dedupe_execute
      patch :dedupe_update_keep
    end
  end
  resources :story_ideas
  resources :stories do
    collection do
      get :share_portal
    end
    member do
      get :show_share_portal
    end
  end
  resources :tutorials
  resources :user_forms
  resources :windows_types
  resources :workshop_ideas
  resources :workshop_logs
  resources :workshop_log_creation_wizard
  resources :workshop_variation_ideas
  resources :workshop_variations
  resources :workshops do
    collection do
      post :search
    end
  end

  resources :workshop_mentions, only: [ :index ]
  resources :resource_mentions, only: [ :index ]
  resources :rich_text_asset_mentions, only: [ :index ]

  namespace :api do
    namespace :v1 do
      resources :authentications, only: [ :create ]
      resources :quotes
      resources :bookmarks
    end
  end

  namespace :dashboard do
    resources :workshops, only: :index
    resources :resources, only: :index
    resources :stories, only: :index
    resources :community_news, only: :index
    resources :events, only: :index
  end

  root to: "dashboard#index"
end
