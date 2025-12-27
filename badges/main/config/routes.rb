Rails.application.routes.draw do

  # temporary direct routes to images for migration audit
  resources :attachments, only: [:show]
  resources :media_files, only: [:show]
  namespace :images do
    resources :main_images, only: [:show]
    resources :gallery_images, only: [:show]
    resources :rich_texts, only: [:show]
  end
  resources :images, only: [:show]

  # mount Ckeditor::Engine, at: '/admin/ckeditor', as: 'ckeditor'
  apipie
  devise_for :users,
             controllers: { registrations: 'registrations',
                            passwords: 'passwords' }
  get 'users/change_password', to: 'users#change_password', as:'change_password'
  post 'users/update_password', to: 'users#update_password', as: 'update_password'

  post 'workshop_logs/validate_new', to: 'workshop_logs#validate_new'

  get 'contact_us', to: 'contact_us#index'
  post 'contact_us', to: 'contact_us#create'
  get 'dashboard/admin', to: 'dashboard#admin'
  get 'dashboard/recent_activities', to: 'dashboard#recent_activities'
  get 'dashboard/help', to: 'dashboard#help'
  get "image_migration_audit", to: "image_migration_audit#index"

  get "taggings", to: "taggings#index", as: "taggings"
  get "taggings/matrix", to: "taggings#matrix", as: "taggings_matrix"
  get "tags", to: "tags#index", as: "tags"
  get "tags/sectors", to: "tags#sectors", as: "tags_sectors"
  get "tags/categories", to: "tags#categories", as: "tags_categories"

  resources :banners
  resources :bookmarks do
    post :search
    collection do
      get :tally
      get :personal
    end
  end
  resources :categories
  resources :community_news
  resources :event_registrations
  resources :events do
    resource :registrations, only: %i[create destroy], module: :events, as: :registrant_registration
  end
  resources :facilitators
  resources :faqs
  resources :notifications, only: [:show]
  resources :organizations
  resources :projects
  resources :project_users
  resources :quotes

  resources :monthly_reports
  get 'reports/:id/edit_story', to: 'reports#edit_story', as: 'reports_edit_story'
  put 'reports/update_story/:id', to: 'reports#update_story', as: 'reports_update_story'
  post 'reports/share_story', to: 'reports#create_story', as: 'create_story'
  get 'reports/share_story', to: 'reports#share_story'

  get 'reports/monthly', to: 'monthly_reports#monthly'
  get 'reports/monthly_select_type', to: 'monthly_reports#monthly_select_type'
  get 'monthly_reports', to: 'monthly_reports#monthly'

  get 'reports/annual', to: 'reports#annual'
  resources :reports

  resources :resources do
    get :download
    member do
      get :rhino_text
    end
    collection do
      post :search
    end
  end
  resources :sectors
  resources :story_ideas
  resources :stories
  resources :users do
    member do
      get :generate_facilitator
    end
  end
  resources :user_forms
  resources :windows_types
  resources :workshop_ideas
  resources :workshop_logs
  resources :workshop_log_creation_wizard
  resources :workshop_variations
  resources :workshops do
    collection do
      post :search
    end
  end

  namespace :api do
    namespace :v1 do
      resources :authentications, only: [:create]
      resources :quotes
      resources :bookmarks
    end
  end

  authenticated :user do
    root to: "dashboard#index", as: :authenticated_root
  end

  # Wrap Devise routes in a scope for unauthenticated users
  devise_scope :user do
    unauthenticated do
      root to: "devise/sessions#new", as: :unauthenticated_root
    end
  end
end
