Rails.application.routes.draw do
  # mount Ckeditor::Engine, at: '/admin/ckeditor', as: 'ckeditor'
  apipie
  get 'cms', to: 'admins/base#show'

  devise_for :users,
             controllers: { registrations: 'registrations',
                            passwords: 'passwords' }

  devise_for :admins

  get 'users/change_password', to: 'users#change_password', as:'change_password'
  post 'users/update_password', to: 'users#update_password', as: 'update_password'

  post 'workshops/create_dummy_workshop', to: 'workshops#create_dummy_workshop'

  post 'workshop_logs/validate_new', to: 'workshop_logs#validate_new'

  get 'impersonate_users', to: 'impersonate_users#index'
  post 'impersonate_users', to: 'impersonate_users#impersonate'
  post 'impersonate_users_back', to: 'impersonate_users#back'
  get 'impersonate_users/help', to: 'impersonate_users#help'


  get 'contact_us', to: 'contact_us#index'
  post 'contact_us', to: 'contact_us#create'
  get 'dashboard/admin', to: 'dashboard#admin'
  get 'dashboard/recent_activities', to: 'dashboard#recent_activities'
  get 'dashboard/help', to: 'dashboard#help'

  resources :workshops do
    collection do
      post :search
    end
  end
  resources :banners
  resources :bookmarks do
    post :search
    resources :annotations
    collection do
      get :tally
      get :personal
    end
  end
  resources :events
  resources :event_registrations, only: [:create, :destroy] do
    collection do
      post :bulk_create
    end
  end

  resources :faqs
  resources :monthly_reports
  resources :project_users

  resources :users do
    member do
      get :generate_facilitator
    end
  end
  resources :user_forms
  resources :facilitators
  resources :organizations

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
    collection do
      post :search
    end
  end

  resources :story_ideas
  resources :stories
  resources :workshop_ideas
  resources :workshop_logs
  resources :workshop_log_creation_wizard
  resources :workshop_variations
  resources :workshops

  namespace :api do
    namespace :v1 do
      resources :authentications, only: [:create]
      resources :quotes
      resources :bookmarks do
        resources :annotations
      end
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
