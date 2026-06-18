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
  authenticate :user, ->(user) { user.super_user? } do
    mount Blazer::Engine, at: "blazer"
  end
  devise_for :users,
             controllers: { registrations: "registrations",
                            confirmations: "confirmations",
                            passwords: "passwords",
                            unlocks: "unlocks" }
  devise_scope :user do
    get "/confirm/:confirmation_token", to: "confirmations#show", as: :confirm
    get "/users/confirmation/resend", to: "confirmations#resend", as: :resend_user_confirmation
  end
  get "users/change_password", to: "users#change_password", as: "change_password"
  post "users/update_password", to: "users#update_password", as: "update_password"
  get "welcome/:welcome_instructions_token", to: "welcome#show", as: "user_welcome"
  patch "welcome/:welcome_instructions_token", to: "welcome#update", as: "user_welcome_update"
  resources :users, only: [ :new, :index, :show, :edit, :update, :create, :destroy ] do
    collection do
      get :check_duplicates
      get :flow_diagram
    end
    member do
      post :send_reset_password_instructions
      post :send_welcome_instructions
      post :toggle_lock_status
      post :confirm_email
      get :confirm_email_change
      post :process_email_change
      get :confirm_email_manual
      post :process_email_manual
    end
    resources :comments, only: [ :index, :create, :update ]
  end

  get "contact_us", to: "contact_us#index"
  post "contact_us", to: "contact_us#create"

  get "taggings", to: "taggings#index", as: "taggings"
  get "taggings/matrix", to: "taggings#matrix", as: "taggings_matrix"
  get "tags", to: "tags#index", as: "tags"
  get "tags/sectors", to: "tags#sectors", as: "tags_sectors"
  get "tags/categories", to: "tags#categories", as: "tags_categories"

  namespace :admin do
    get "/",                         to: "home#index" # admin home page
    get "activities/events",         to: "ahoy_activities#index", as: "activities_events"
    get "activities/events/:id",    to: "ahoy_activities#show", as: "activities_event"
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
  resources :category_types
  resources :categories do
    collection do
      get :dedupe_index
      get :dedupe_preview
      post :dedupe_execute
      patch :dedupe_update_keep
    end
  end
  resources :community_news
  get "bulk_payment/:slug", to: "events/bulk_payments#ticket", as: :bulk_payment_ticket
  post "bulk_payment/:slug/resend_confirmation", to: "events/bulk_payments#resend_confirmation", as: :bulk_payment_resend_confirmation
  get "registration/:slug", to: "events/registrations#show", as: :registration_ticket
  get "registration/:slug/invoice", to: "events/registrations#invoice", as: :registration_invoice
  post "registration/:slug/resend_confirmation", to: "events/registrations#resend_confirmation", as: :registration_resend_confirmation
  post "registration/:slug/cancel", to: "events/registrations#cancel", as: :registration_cancel
  post "registration/:slug/reactivate", to: "events/registrations#reactivate", as: :registration_reactivate
  post "registration/:slug/pay", to: "events/registrations#pay", as: :registration_pay
  resources :event_registrations do
    member do
      get :confirm
      post :process_confirm
      get :link_organization
      post :select_organization
      post :create_organization
      delete :unlink_organization
    end
    resources :comments, only: [ :index, :create, :update ]
  end
  resources :forms do
    member do
      patch :reorder_field
      put :reorder_fields
      get :edit_sections
      patch :update_sections
    end
  end
  resources :form_submissions, only: [ :show ]
  resources :grants
  resources :scholarships, only: [ :new, :create, :show, :edit, :update, :destroy ] do
    member { patch :toggle_tasks }
  end
  resources :discounts, only: [ :create, :show, :destroy ] do
    collection do
      post :allocation_form
    end
  end
  resources :events do
    member do
      get :dashboard
      get :background
      get :registrants
      get :details
      get :ce_hours
      get :staff
      get "staff/edit", action: :edit_staff, as: :edit_staff
      patch "staff", action: :update_staff
      get :recipients
      get :bulk_payments
      get :preview_reminder
      patch :preview
      post :copy_registration_form
      post :send_reminder
      post :allocate_bulk_payment
      post :create_bulk_payment
    end
    resources :registration_ticket_callouts, only: [ :show, :update ]
    resource :registrations, only: %i[ create destroy ], module: :events, as: :registrant_registration
    resource :public_registration, only: [ :new, :create, :show ], module: :events
    resource :bulk_payment, only: [ :new, :create, :show ], module: :events
    resource :invoice, only: [ :show ], module: :events
  end
  resources :people do
    collection do
      get :check_duplicates
    end
    member do
      get :workshop_logs
      get :checkout
      get :bio
    end
    resources :comments, only: [ :index, :create, :update ]
  end
  resources :faqs
  resources :notifications, only: [ :index, :show, :update ] do
    member do
      post :resend
    end
  end
  resources :organizations do
    collection do
      get :check_duplicates
    end
    member do
      get :populations_served
    end
    resources :comments, only: [ :index, :create, :update ]
    resources :monthly_reports, only: :index
  end
  resources :payments, only: [ :new, :create, :show, :index ] do
    collection do
      post :allocation_form
      get :new_checkout_link
      post :create_checkout_link
    end
  end
  resources :allocations, only: [ :new, :create, :index ] do
    post :revert, on: :member
  end

  resources :refunds, only: [ :new, :create, :show ]
  resources :organization_statuses
  resources :affiliations
  resources :quotes

  resources :monthly_reports, only: [ :index, :show ], constraints: { id: /\d+/ }
  get "reports/:id/edit_story", to: "reports#edit_story", as: "reports_edit_story"
  put "reports/update_story/:id", to: "reports#update_story", as: "reports_update_story"
  post "reports/share_story", to: "reports#create_story", as: "create_story"
  get "reports/share_story", to: "reports#share_story"

  get "reports/annual", to: "reports#annual"
  resources :reports

  resources :resources do
    get :download
  end
  resources :sectors do
    collection do
      get :dedupe_index
      get :dedupe_preview
      post :dedupe_execute
      patch :dedupe_update_keep
    end
  end
  get "search/:model", to: "search#index"
  resources :story_ideas
  resources :stories
  resources :story_shares, only: [ :index, :show ]
  resources :video_recordings
  resources :user_forms
  resources :windows_types
  resources :workshop_ideas
  resources :workshop_logs

  resources :workshop_variation_ideas
  resources :workshop_variations
  resources :workshops do
    resources :comments, only: [ :index, :create, :update ]
  end

  resources :workshop_mentions, only: [ :index ]
  resources :resource_mentions, only: [ :index ]
  resources :rich_text_asset_mentions, only: [ :index ]
  resources :event_mentions, only: [ :index ]

  namespace :home do
    resources :workshops, only: :index
    resources :resources, only: :index
    resources :stories, only: :index
    resources :community_news, only: :index
    resources :events, only: :index
    resources :video_recordings, only: :index
  end

  root to: "home#index"
end
