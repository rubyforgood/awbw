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
    @created
  end
end
