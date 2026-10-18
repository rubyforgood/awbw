# frozen_string_literal: true

# Create the "Workshop Settings" category type and its options without running the full
# db:seed (WorkshopSettingsSeeder). Idempotent, so it's safe to run in prod and to re-run;
# an option no longer offered is unpublished, never deleted.
#
#   bin/rails data:seed_workshop_settings
namespace :data do
  desc "Create the Workshop Settings category type and its options (idempotent)."
  task seed_workshop_settings: :environment do
    type = WorkshopSettingsSeeder.call
    puts "Workshop Settings: #{type.categories.published.count} published options."
  end
end
