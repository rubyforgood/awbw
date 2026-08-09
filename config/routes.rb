Rails.application.routes.draw do
  resources :primary_assets
  resources :rich_text_assets

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
    resources :comments, only: [ :index ]
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
      post :dedupe_perform
      patch :dedupe_update_keep
    end
  end
  resources :community_news
  get "bulk_payment/:slug", to: "events/bulk_payment_form_submissions#ticket", as: :bulk_payment_ticket
  post "bulk_payment/:slug/resend_confirmation", to: "events/bulk_payment_form_submissions#resend_confirmation", as: :bulk_payment_resend_confirmation
  get "registration/:slug", to: "events/registrations#show", as: :registration_ticket
  get "registration/:slug/invoice", to: "events/registrations#invoice", as: :registration_invoice
  get "registration/:slug/receipt", to: "events/registrations#receipt", as: :registration_receipt
  get "registration/:slug/scholarship", to: "events/callouts#scholarship", as: :registration_scholarship
  post "registration/:slug/scholarship/agreement", to: "events/callouts#sign_agreement", as: :registration_scholarship_agreement
  get "registration/:slug/faq", to: "events/callouts#faq", as: :registration_faq
  get "registration/:slug/payment", to: "events/callouts#payment", as: :registration_payment
  get "registration/:slug/certificate", to: "events/callouts#certificate", as: :registration_certificate
  get "registration/:slug/ce", to: "events/callouts#ce", as: :registration_ce
  post "registration/:slug/ce/license", to: "events/callouts#update_ce_license", as: :registration_ce_license
  post "registration/:slug/ce/request", to: "events/callouts#request_ce", as: :registration_ce_request
  post "registration/:slug/ce/pay", to: "events/callouts#pay_ce", as: :registration_ce_pay
  get "registration/:slug/handouts", to: "events/callouts#handouts", as: :registration_handouts
  get "registration/:slug/resource/:resource_id", to: "events/callouts#resource", as: :registration_resource
  get "registration/:slug/videoconference", to: "events/callouts#videoconference", as: :registration_videoconference
  get "registration/:slug/staff", to: "events/callouts#staff", as: :registration_staff
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
      patch :update_onboarding
      patch :toggle_certificate_issued
    end
    resources :comments, only: [ :index, :create, :update ]
  end
  resources :topic_subscriptions, except: [ :show ] do
    collection do
      get :email_addresses
    end
    member do
      patch :unsubscribe
      patch :resubscribe
    end
    resources :comments, only: [ :index, :create, :update ]
  end
  resources :topic_subscription_types, except: [ :show ] do
    member do
      patch :archive
      patch :unarchive
    end
  end
  resources :forms do
    member do
      patch :reorder_field
      put :reorder_fields
      get :edit_sections
      patch :update_sections
    end
  end
  resources :form_submissions, only: [ :index, :show ]
  resources :grants
  resources :scholarships, only: [ :index, :new, :create, :show, :edit, :update, :destroy ] do
    member { patch :toggle_tasks }
    resources :comments, only: [ :index, :create, :update ]
  end
  resources :continuing_education_registrations, only: [ :new, :create, :edit, :update, :destroy ] do
    member { patch :toggle_certificate }
    resources :comments, only: [ :index, :create, :update ]
  end
  resources :discounts, only: [ :create, :show, :destroy ] do
    collection do
      post :allocation_form
    end
  end
  resources :events do
    collection do
      get :revenue
      get :participation
      get :statistics
      get :scholarships
      get :training_attendees
    end
    member do
      get :dashboard
      get :sample_ticket
      # Admin-only in-memory previews of the behavioral built-in callout pages,
      # linked from the sample ticket. They reuse Events::CalloutsController's
      # actions/views with an unsaved sample registration (see its sample mode).
      get "sample_ticket/payment", to: "events/callouts#payment", defaults: { sample: "1" }, as: :sample_payment
      get "sample_ticket/certificate", to: "events/callouts#certificate", defaults: { sample: "1" }, as: :sample_certificate
      get "sample_ticket/scholarship", to: "events/callouts#scholarship", defaults: { sample: "1" }, as: :sample_scholarship
      get "sample_ticket/ce", to: "events/callouts#ce", defaults: { sample: "1" }, as: :sample_ce
      get "sample_ticket/videoconference", to: "events/callouts#videoconference", defaults: { sample: "1" }, as: :sample_videoconference
      get "sample_ticket/staff", to: "events/callouts#staff", defaults: { sample: "1" }, as: :sample_staff
      get :background
      get :registrants
      get :onboarding
      get :staff
      get "staff/edit", action: :edit_staff, as: :edit_staff
      patch "staff", action: :update_staff
      get :recipients
      post :feature_recipient_shoutout
      get :bulk_payments, to: "events/bulk_payments#index"
      get :preview_reminder
      patch :preview
      post :copy_registration_form
      post :confirm_reminder
      post :send_reminder
      post :allocate_bulk_payment, to: "events/bulk_payments#allocate"
      post :bulk_payments, to: "events/bulk_payments#create"
      post :link_bulk_payment, to: "events/bulk_payments#link"
      delete :unlink_bulk_payment, to: "events/bulk_payments#unlink"
    end
    resources :registration_ticket_callouts, only: [ :show, :update ]
    resource :registrations, only: %i[ create ], module: :events, as: :registrant_registration
    resource :public_registration, only: [ :new, :create, :show ], module: :events
    resource :bulk_payment, only: [ :new, :create, :show ], controller: "events/bulk_payment_form_submissions"
    resource :invoice, only: [ :show ], module: :events
    get "form_submissions/:person_id", to: "events/form_submissions#show", as: :registrant_submissions
  end
  resources :people do
    collection do
      get :check_duplicates
    end
    member do
      get :workshop_logs
      get :checkout
      get :bio
      get :all_comments
    end
    resources :comments, only: [ :index, :create, :update ]
    resources :memberships, only: [ :index, :new, :create ]
  end
  resources :faqs
  resources :other_responses, only: [ :index, :update ] do
    collection do
      post :promote
      post :curate
    end
  end
  resources :notifications, only: [ :index, :new, :create, :show, :update ] do
    member do
      post :resend
    end
  end
  # Friendly alias — the feature is called "Communications" in the UI, but the
  # controller and routes stay :notifications. Redirect, preserving any filters.
  get "communications", to: redirect { |_params, req| [ "/notifications", req.query_string.presence ].compact.join("?") }, as: :communications
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
  resources :payments, only: [ :new, :create, :show, :index, :edit, :update ] do
    collection do
      post :allocation_form
      get :new_checkout_link
      post :create_checkout_link
    end
  end
  resources :allocations, only: [ :new, :create, :index ] do
    post :revert, on: :member
  end

  resources :memberships, only: [ :edit, :update ] do
    resources :membership_invoices, only: [ :new, :create ]
  end

  resources :membership_invoices, only: [ :index, :show, :edit, :update ]
  resources :membership_checkouts, only: [ :create ]

  resources :refunds, only: [ :new, :create, :show ]
  resources :organization_statuses
  resources :affiliations, only: :destroy
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
      post :dedupe_perform
      patch :dedupe_update_keep
    end
  end
  get "search/:model", to: "search#index"
  resources :story_ideas
  resources :stories
  resources :story_shares, only: [ :index, :show ] do
    get :share, on: :collection
  end
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
