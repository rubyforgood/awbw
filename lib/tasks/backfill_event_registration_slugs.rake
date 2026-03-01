namespace :event_registrations do
  desc "Backfill slugs for existing event registrations"
  task backfill_slugs: :environment do
    count = 0
    EventRegistration.where(slug: nil).find_each do |registration|
      registration.update_column(:slug, SecureRandom.urlsafe_base64(16))
      count += 1
    end
    puts "Backfilled #{count} event registration slugs"
  end
end
