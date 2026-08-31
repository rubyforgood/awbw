# frozen_string_literal: true

# Create the survey template forms the built-in callouts deliver — the Day 1 / Day 2
# training evaluations and the scholarship recipients survey — without running the
# full db:seed. Built from the form-builder presets (SurveyFormSeeder), idempotent
# on form name, so it's safe to run in prod and safe to re-run.
#
# Run this before events pick up the survey callouts: the built-ins link their forms
# by name, so the forms must exist first. (The Post-event survey built-in appears on
# an event when its editor is next opened; an existing scholarship callout needs a
# "Restore default" to pick up the recipients survey row.)
#
#   bin/rails data:seed_survey_forms
namespace :data do
  desc "Create the Day 1 / Day 2 / recipients survey template forms (idempotent). Run before configuring the survey callouts."
  task seed_survey_forms: :environment do
    created = SurveyFormSeeder.call
    if created.any?
      puts "Created #{created.size} survey form(s): #{created.join(", ")}"
    else
      puts "All survey forms already exist — nothing to create."
    end
  end
end
