require Rails.root.join('lib', 'rails_admin', 'duplicate.rb')
RailsAdmin::Config::Actions.register(RailsAdmin::Config::Actions::Duplicate)
RailsAdmin.config do |config|

  config.navigation_static_links = {
    'Help' => '/dashboard/help'
  }

  ### Popular gems integration

  ## == Devise ==
  config.authenticate_with do
    warden.authenticate! scope: :admin
  end
  config.current_user_method(&:current_admin)

  ## == Cancan ==
  # config.authorize_with :cancan

  ## == PaperTrail ==
  # config.audit_with :paper_trail, 'User', 'PaperTrail::Version' # PaperTrail >= 3.0.0

  ### More at https://github.com/sferik/rails_admin/wiki/Base-configuration

  config.actions do
    dashboard                     # mandatory
    index                         # mandatory
    new
    export
    bulk_delete
    show
    edit
    delete
    duplicate
    # show_in_app

    ## With an audit adapter, you can add:
    # history_index
    # history_show
  end

  config.model 'WindowsType' do
    object_label_method do
      :custom_label_method
    end
  end

  config.model 'Resource' do
    object_label_method do
      :custom_label_list
    end
  end

  config.model 'Workshop' do
    configure :english_anchors do
      pretty_value do
        anchors = bindings[:object]
        Workshop.anchors_english_admin
      end
      read_only true
    end
    configure :spanish_anchors do
      pretty_value do
        anchors = bindings[:object]
        Workshop.anchors_spanish_admin
      end
      read_only true
    end
  end
  config.default_associated_collection_limit = 1500
end
