# Creates the standalone survey template forms the built-in callouts deliver: the
# Day 1 and Day 2 training evaluations (everyone, on the Post-event survey callout)
# and the scholarship recipients survey (on the scholarship callout). Built once
# from the form-builder presets, then left for staff to edit in the builder.
#
# Idempotent on form name, so it's safe to run repeatedly — in db/seeds and as the
# `data:seed_survey_forms` task for prod. Returns the names it created (skipping
# any that already exist).
class SurveyFormSeeder
  TEMPLATES = [
    { name: "Day 1 Survey", role: "day_1_survey", sections: %i[day_1_survey content_sharing_preferences] },
    { name: "Day 2 Survey", role: "day_2_survey", sections: %i[day_2_survey content_sharing_preferences] },
    { name: "Post-Training Recipients Survey", role: "recipient_survey", sections: %i[recipient_survey content_sharing_preferences] }
  ].freeze

  DAY_1_WORKSHOPS = [ "The Touchstone Journey", "Creating A Safer/Braver Place", "The Take A Break, Self-Regulate" ].freeze
  DAY_2_WORKSHOPS = [ "The Monster In Me", "Claiming Who I Am" ].freeze

  # Each fan-out anchor (by field_identifier) fans over the training topics it asks
  # about — resources matched by title. The growth questions cover the whole day's
  # workshops; the clarity questions use a default split. Admins adjust any of it per
  # form in the editor's "Fan out per resource".
  FANOUT_RESOURCES = {
    "d1_clarity_part_one" => [ "The Touchstone Journey", "Creating A Safer/Braver Place" ],
    "d1_clarity_part_two" => [ "The Take A Break, Self-Regulate" ],
    "d1_growth_personal" => DAY_1_WORKSHOPS,
    "d1_growth_professional" => DAY_1_WORKSHOPS,
    "d2_clarity_part_one" => [ "The Monster In Me" ],
    "d2_clarity_part_two" => [ "Claiming Who I Am" ],
    "d2_growth_personal" => DAY_2_WORKSHOPS,
    "d2_growth_professional" => DAY_2_WORKSHOPS
  }.freeze

  def self.call
    new.call
  end

  attr_reader :created

  def initialize
    @created = []
  end

  def call
    TEMPLATES.each do |template|
      next if Form.exists?(name: template[:name])
      FormBuilderService.new(name: template[:name], sections: template[:sections], role: template[:role]).call
      @created << template[:name]
    end
    link_fanout_resources
    @created
  end

  # Link each fan-out question to its topics (resources matched by title). Idempotent
  # — skips existing links and skips a resource that isn't present (prod already has
  # them; the dev sample seed creates them). Safe to call on its own after the forms
  # and resources exist.
  def link_fanout_resources
    FANOUT_RESOURCES.each do |identifier, titles|
      FormField.where(field_identifier: identifier).find_each do |field|
        Resource.where(title: titles).find_each do |resource|
          field.form_field_resources.find_or_create_by!(resource: resource)
        end
      end
    end
  end
end
