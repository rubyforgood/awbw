class MonthlyReport < Report

  rails_admin do
    configure :created_at do
      show
    end
    configure :updated_at do
      show
    end

    list do
      field :id
      field :type
      field :created_at do
        column_width 200
      end
      field :project do
        searchable true
        queryable true
        searchable [:name]
      end
      field :date do
        label do
          "Month"
        end
        strftime_format "%m"
        filterable true
        searchable true
        queryable true
        column_width 110
      end
      field :windows_type do
        filterable false
        visible false
      end
      field :on_going_participants do
        column_width 10
      end
      field :new_participants do
        column_width 10
      end
      field :has_attachment do
        filterable true
        searchable true
        column_width 40
      end
      configure :on_going_participants do
        formatted_value{ bindings[:object].on_going_participants}
      end

      configure :new_participants do
        formatted_value{ bindings[:object].new_participants}
      end

      configure :type do
        formatted_value{ bindings[:object].admin_type}
      end

      configure :date do
        formatted_value{ bindings[:object].month}
      end

    end
  end

  def on_going_participants
    if form_builder
      field = form_builder.form_fields.find_by(question: 'Total # On-going Participants', status: 1)
      field.answer(self) if field
    end
  end

  def new_participants
    if form_builder
      field = form_builder.form_fields.find_by(question: 'Total # First-Time Participants', status: 1)
      field.answer(self) if field
    end
  end

  def month
    date.strftime("%B")
  end


end
