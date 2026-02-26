namespace :db do
  namespace :dev do
    desc "Generate dev seed data"
    task seed: :environment do
      load Rails.root.join("db/seeds/dummy_dev_seeds.rb")
    end
  end
end
