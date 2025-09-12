class Story < Report
  rails_admin do
    configure :owner do
      hide
    end
    list do
      field :id do
        column_width 50
      end
      field :type do
        column_width 50
      end

      field :windows_type do
        filterable true
        queryable true
        searchable [:name]
        column_width 110
      end
      field :user do
        column_width 90
      end
      field :project do
        column_width 120
      end
      field :created_at do
        column_width 120
      end
      field :has_attachment do
        filterable true
        searchable true
        column_width 10
      end

    end
  end
end
