namespace :db do
  namespace :seed do
    desc "Generate representative sample data for development"
    task dev: [ :environment, "db:seed", "db:seed:dummy", "db:seed:payments" ]

    desc "Seed generic dummy dev data (workshops, people, stories, etc.)"
    task dummy: :environment do
      load Rails.root.join("db/seeds/dev/dummy.rb")
    end

    desc "Seed sample payments, allocations, and refunds (dev only)"
    task payments: :environment do
      load Rails.root.join("db/seeds/dev/payments.rb")
    end
  end
end
