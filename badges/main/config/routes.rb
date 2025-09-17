Rails.application.routes.draw do
  mount Ckeditor::Engine => '/admin/ckeditor', as: 'ckeditor'
  apipie
  get 'cms', to: 'admins/base#show'

  devise_for :users, controllers: { registrations: 'registrations', passwords: 'passwords' }

  devise_for :admins

  get 'users/:id/change_password', to: 'users#change_password', as:'change_password'
  post 'users/:id/update_password', to: 'users#update_password'

  get 'workshops/share_idea', to: 'workshops#share_idea'
  get 'workshops/summary', to: 'workshops#summary'
  get 'workshops/:id/share_idea_show', to: 'workshops#share_idea_show',
      as: 'share_idea_show'

  post 'workshops/create_workshop_idea', to: 'workshops#create_workshop_idea'
  post 'workshops/create_dummy_workshop', to: 'workshops#create_dummy_workshop'

  post 'workshop_logs/validate_new', to: 'workshop_logs#validate_new'

  get 'impersonate_users', to: 'impersonate_users#index'
  post 'impersonate_users', to: 'impersonate_users#impersonate'
  post 'impersonate_users_back', to: 'impersonate_users#back'
  get 'impersonate_users/help', to: 'impersonate_users#help'

  resources :workshops do
    collection do
      post :search
    end
  end

  resources :bookmarks do
    post :search
    resources :annotations
  end

  resources :workshop_log_creation_wizard
  resources :workshop_logs, only: [:show, :edit, :new, :create, :update]

  resources :events
  resources :event_registrations, only: [:create] do
    collection do
      post :bulk_create
    end
  end

  get 'stories', to: 'resources#stories'

  resources :users
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

  get 'contact_us', to: 'contact_us#index'
  post 'contact_us', to: 'contact_us#create'
  get 'dashboard/recent_activity', to: 'dashboard#recent_activity'
  get 'dashboard/help', to: 'dashboard#help'

  resources :monthly_reports
  resources :faqs
  resources :project_users
  resources :workshops
  resources :workshop_variations, only: [:show]
  root 'dashboard#index'

  namespace :api do
    namespace :v1 do
      resources :authentications, only: [:create]
      resources :quotes
      resources :bookmarks do
        resources :annotations
      end
    end
  end
end
