namespace :db do
  namespace :seed do
    # Each dev seed file is independent: it can be run on its own via its own
    # task, and looks up (rather than requires) data from the other dev seeds,
    # skipping gracefully when that data is absent. db:seed:dev runs them in
    # dependency order after the base db:seed so the full sample set is built.
    dev_seed_files = %w[
      organizations
      workshops
      quotes
      people_profiles
      home_page_content
      workshop_logs
      monthly_reports
      events_management
      resources
      faqs
      video_recordings
      notifications
      bookmarks
      analytics
      payments
      scholarships
      bulk_payments
      legacy_form_identifiers
    ]

    desc "Generate representative sample data for development"
    task dev: [ :environment, "db:seed", "db:seed:users" ] + dev_seed_files.map { |name| "db:seed:#{name}" }

    desc "Seed dev-only user variations (invite/lock/confirmation states)"
    task users: :environment do
      load Rails.root.join("db/seeds/dev/users.rb")
    end

    desc "Seed dev organizations"
    task organizations: :environment do
      load Rails.root.join("db/seeds/dev/organizations.rb")
    end

    desc "Seed dev workshops, categories/sectors, and variations"
    task workshops: :environment do
      load Rails.root.join("db/seeds/dev/workshops.rb")
    end

    desc "Seed dev quotes and workshop-quote links"
    task quotes: :environment do
      load Rails.root.join("db/seeds/dev/quotes.rb")
    end

    desc "Seed dev people profiles, affiliations, and addresses/sectors"
    task people_profiles: :environment do
      load Rails.root.join("db/seeds/dev/people_profiles.rb")
    end

    desc "Seed dev home page content (news, ideas, stories)"
    task home_page_content: :environment do
      load Rails.root.join("db/seeds/dev/home_page_content.rb")
    end

    desc "Seed dev workshop logs"
    task workshop_logs: :environment do
      load Rails.root.join("db/seeds/dev/workshop_logs.rb")
    end

    desc "Seed dev monthly reports"
    task monthly_reports: :environment do
      load Rails.root.join("db/seeds/dev/monthly_reports.rb")
    end

    desc "Seed dev events, registrations, and form submissions"
    task events_management: :environment do
      load Rails.root.join("db/seeds/dev/events_management.rb")
    end

    desc "Seed dev resources"
    task resources: :environment do
      load Rails.root.join("db/seeds/dev/resources.rb")
    end

    desc "Seed dev FAQs"
    task faqs: :environment do
      load Rails.root.join("db/seeds/dev/faqs.rb")
    end

    desc "Seed dev video recordings"
    task video_recordings: :environment do
      load Rails.root.join("db/seeds/dev/video_recordings.rb")
    end

    desc "Seed dev notifications"
    task notifications: :environment do
      load Rails.root.join("db/seeds/dev/notifications.rb")
    end

    desc "Seed dev bookmarks for seed users"
    task bookmarks: :environment do
      load Rails.root.join("db/seeds/dev/bookmarks.rb")
    end

    desc "Seed dev analytics (Ahoy visits and events)"
    task analytics: :environment do
      load Rails.root.join("db/seeds/dev/analytics.rb")
    end

    desc "Seed sample payments, allocations, and refunds (dev only)"
    task payments: :environment do
      load Rails.root.join("db/seeds/dev/payments.rb")
    end

    desc "Seed sample scholarships and their allocations (dev only)"
    task scholarships: :environment do
      load Rails.root.join("db/seeds/dev/scholarships.rb")
    end

    desc "Seed bulk payment demo submissions, payments, and allocations (dev only)"
    task bulk_payments: :environment do
      load Rails.root.join("db/seeds/dev/bulk_payments.rb")
    end

    desc "Seed registration forms using legacy professional-field identifiers (dev only)"
    task legacy_form_identifiers: :environment do
      load Rails.root.join("db/seeds/dev/legacy_form_identifiers.rb")
    end
  end
end
