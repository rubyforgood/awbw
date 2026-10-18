# Creates the standalone survey template forms the built-in callouts deliver: the
# Day 1 / Day 2 evaluations and the overall post-event survey (everyone, on the
# Feedback surveys callout), and the scholarship recipients survey (on the
# scholarship callout). Built once from the form-builder presets, then left for
# staff to edit in the builder.
#
# Idempotent on form name, so it's safe to run repeatedly — in db/seeds and as the
# `data:seed_survey_forms` task for prod. Returns the names it created (skipping
# any that already exist).
class SurveyFormSeeder
  # BuiltinCallouts finds these forms by name.
  DAY_1_FORM_NAME = "Day 1 Survey".freeze
  DAY_2_FORM_NAME = "Day 2 Survey".freeze
  POST_EVENT_FORM_NAME = "Post-Event Survey".freeze
  RECIPIENTS_FORM_NAME = "Post-Training Recipients Survey".freeze

  TEMPLATES = [
    { name: DAY_1_FORM_NAME, sections: %i[day_1_survey content_sharing_preferences] },
    { name: DAY_2_FORM_NAME, sections: %i[day_2_survey content_sharing_preferences] },
    { name: POST_EVENT_FORM_NAME, sections: %i[post_event_feedback content_sharing_preferences] },
    { name: RECIPIENTS_FORM_NAME, sections: %i[recipient_survey content_sharing_preferences] }
  ].freeze

  DAY_1_WORKSHOPS = [ "The Touchstone Journey", "Creating A Safer/Braver Place", "The Take A Break, Self-Regulate" ].freeze
  DAY_2_WORKSHOPS = [ "The Monster In Me", "Claiming Who I Am" ].freeze

  # Each fan-out question fans over the training topics it asks about — resources
  # matched by title. The questions carry no identifier (their answers only live on
  # the submission), so they're matched by prompt (+ subtitle for the clarity pair).
  # The growth questions cover the whole day's workshops; clarity uses a default
  # split. Admins adjust any of it per form in the editor's "Fan out per resource".
  FANOUT_RESOURCES = [
    { form: DAY_1_FORM_NAME, name: FormBuilderService::CLARITY_PROMPT, subtitle: "Day 1 — Part One", resources: [ "The Touchstone Journey", "Creating A Safer/Braver Place" ] },
    { form: DAY_1_FORM_NAME, name: FormBuilderService::CLARITY_PROMPT, subtitle: "Day 1 — Part Two", resources: [ "The Take A Break, Self-Regulate" ] },
    { form: DAY_1_FORM_NAME, name: FormBuilderService::GROWTH_PERSONAL_PROMPT, resources: DAY_1_WORKSHOPS },
    { form: DAY_1_FORM_NAME, name: FormBuilderService::GROWTH_PROFESSIONAL_PROMPT, resources: DAY_1_WORKSHOPS },
    { form: DAY_2_FORM_NAME, name: FormBuilderService::CLARITY_PROMPT, subtitle: "Day 2 — Part 1", resources: [ "The Monster In Me" ] },
    { form: DAY_2_FORM_NAME, name: FormBuilderService::CLARITY_PROMPT, subtitle: "Day 2 — Part 2", resources: [ "Claiming Who I Am" ] },
    { form: DAY_2_FORM_NAME, name: FormBuilderService::GROWTH_PERSONAL_PROMPT, resources: DAY_2_WORKSHOPS },
    { form: DAY_2_FORM_NAME, name: FormBuilderService::GROWTH_PROFESSIONAL_PROMPT, resources: DAY_2_WORKSHOPS }
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
      FormBuilderService.new(name: template[:name], sections: template[:sections], role: "general").call
      @created << template[:name]
    end
    link_fanout_resources
    @created
  end

  # Link each fan-out question to its topics (resources matched by exact title).
  # Idempotent — skips existing links and any resource that isn't present (the dev
  # sample seed creates them; anywhere else they must be added first). Safe to call
  # on its own after the forms and resources exist.
  def link_fanout_resources
    FANOUT_RESOURCES.each do |entry|
      form = Form.find_by(name: entry[:form])
      next unless form
      scope = form.form_fields.where(name: entry[:name])
      scope = scope.where(subtitle: entry[:subtitle]) if entry[:subtitle]
      scope.find_each do |field|
        Resource.where(title: entry[:resources]).find_each do |resource|
          field.form_field_resources.find_or_create_by!(resource: resource)
        end
      end
    end
  end
end
