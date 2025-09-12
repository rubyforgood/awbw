FactoryBot.define do
  factory :report do
    # Associations
    association :user
    association :project
    association :windows_type # Needed by callbacks/logic
    # Polymorphic association: belongs_to :owner (can be nil or another model like FormBuilder)
    owner { nil } # Default owner

    # STI type column
    type { "Report" } # Default type, override for MonthlyReport, WorkshopLog etc.

    # Other potential attributes
    date { Date.today }

    # Paperclip attributes (placeholders)
    form_file_file_name { nil }
    form_file_content_type { nil }
    form_file_file_size { nil }
    form_file_updated_at { nil }

    # Callbacks might require other associated data (e.g., form fields for form_builder)
    # Consider traits or transient attributes for complex setup.
  end

  # Specific factory for MonthlyReport inheriting from Report
  factory :monthly_report, parent: :report, class: 'MonthlyReport' do
    type { "MonthlyReport" }
    # Add specific attributes or associations for MonthlyReport if needed
  end
end 