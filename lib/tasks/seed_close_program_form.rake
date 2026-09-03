# frozen_string_literal: true

# Create the standalone "Close Program" agreement form without running the full
# db:seed. Built from the form-builder presets (CloseProgramFormSeeder),
# idempotent on form name, so it's safe to run in prod and safe to re-run. Staff
# give it a slug and publish it in the form builder before sending its link.
#
#   bin/rails data:seed_close_program_form
namespace :data do
  desc "Create the Close Program agreement form (idempotent). Give it a slug and publish it in the form builder to use it."
  task seed_close_program_form: :environment do
    created = CloseProgramFormSeeder.call
    if created
      puts "Created the #{created} form."
    else
      puts "The Close Program form already exists — nothing to create."
    end
  end
end
