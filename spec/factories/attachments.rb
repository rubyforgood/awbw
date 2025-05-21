FactoryBot.define do
  factory :attachment do
    # Polymorphic association: belongs_to :owner
    # Needs an owner instance, e.g.:
    association :owner, factory: :user

    # Paperclip attributes (placeholders)
    # Setting up file attachments in factories usually requires more setup
    # or helper methods to create valid file objects.
    file_file_name { "test.pdf" }
    file_content_type { "application/pdf" }
    file_file_size { 1024 }
    file_updated_at { Time.zone.now }

    # A minimal factory might skip the file if not strictly needed for validation
    # or associate with a pre-existing owner if that's sufficient for the test.
  end
end 