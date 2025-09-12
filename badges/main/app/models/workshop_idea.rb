class WorkshopIdea < Workshop

  default_scope { where(inactive: true) }

    # Rails Admin
  rails_admin do
    field :title
    field :created_at
    field :full_name do
      label 'Author'
    end

    field :month
    field :year
    field :featured
    field :objective, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end

    field :materials, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end

    field :optional_materials, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :age_range
    field :setup, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :introduction, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end

    field :time_intro do
      label 'Time Frame Introduction'
    end

    field :demonstration, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end

    field :time_demonstration do
      label 'Time Frame Demo'
    end

    field :opening_circle, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
      label 'Opening'
    end

    field :time_opening do
      label 'Time Frame Opening'
    end

    field :warm_up, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
      label 'Warm-up / Relaxation / Meditation'
    end

    field :time_warm_up do
      label 'Time Frame Warm Up'
    end

    field :visualization, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end

    field :creation, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end

    field :time_creation do
      label 'Time Frame Creation'
    end

    field :closing, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end

    field :time_closing do
      label 'Time Frame Closing'
    end

    field :notes, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :tips, :ck_editor do
      pretty_value do 
        value.html_safe unless value.nil?
      end
    end
    field :misc1, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :misc2, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end

    field :objective_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :materials_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :optional_materials_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :timeframe_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :age_range_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :setup_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :introduction_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :demonstration_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :opening_circle_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end

      label 'Opening Spanish'
    end
    field :warm_up_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
      label 'Warm-up / Relaxation / Meditation Spanish'
    end
    field :visualization_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :creation_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :closing_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :notes_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :tips_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :misc1_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end
    field :misc2_spanish, :ck_editor do
      pretty_value do
        value.html_safe unless value.nil?
      end
    end

    field :workshop_variations
    field :sectorable_items
    field :categories
    field :quotes
    field :images
    field :inactive
    field :windows_type
    field :header
    field :thumbnail
    field :legacy

    object_label_method do
      :admin_title
    end

    show do
      field :month
      field :year
    end

    list do
      sort_by :created_at

      field :created_at do
        sort_reverse true
      end

      configure :title do
        formatted_value{ bindings[:object].admin_title }
      end
    end

    exclude_fields :categorizable_items, :quotable_item_quotes, :timestamps,
                   :workshop_resources, :resources, :legacy_id, :workshop_age_ranges,
                   :workshop_logs, :metadata, :bookmarks, :user, :misc1, :misc2, :reports

  end

end
