# Creates the "Workshop Settings" category type (WorkshopEnvironment) — where a facilitator
# runs workshops, picked on the person edit form and charted on event dashboards — and its
# canonical options. Shared by db/seeds and the `data:seed_workshop_settings` task, since
# deploys never run db:seed. Idempotent, and never deletes an option: one no longer offered
# is unpublished so its taggings survive.
class WorkshopSettingsSeeder
  TYPE_NAME = "WorkshopEnvironment".freeze
  TYPE_ATTRIBUTES = { display_text: "Workshop Settings", story_specific: false, profile_specific: true, published: true }.freeze

  # In display order. The registration form's parenthetical examples live in each option's
  # description, shown as subtext so the label stays a clean, clickable phrase.
  SETTINGS = [
    [ "Clinical setting", "Community mental health, outpatient, etc" ],
    [ "Educational setting", "Schools, universities, etc" ],
    [ "Events and conferences", nil ],
    [ "Faith-based setting", nil ],
    [ "Home visits", nil ],
    [ "Hospitals", nil ],
    [ "Law enforcement/court/legal", nil ],
    [ "Outreach program", "Drop-in services, support groups, etc" ],
    [ "Prisons/jails", nil ],
    [ "Private practice", nil ],
    [ "Residential program", "Emergency shelters, inpatient, etc" ],
    [ "Virtually", nil ],
    [ "With staff", nil ],
    [ "Other", "Please specify below." ]
  ].freeze

  def self.call
    new.call
  end

  def call
    park_positions
    SETTINGS.each_with_index { |(name, description), index| reconcile(name, description, index + 1) }
    unpublish_retired
    type
  end

  private

  def type
    @type ||= (CategoryType.find_by(name: TYPE_NAME) || CategoryType.new(name: TYPE_NAME)).tap { |t| t.update!(TYPE_ATTRIBUTES) }
  end

  # Moves every position above the canonical range so 1..N can be reassigned without
  # tripping the unique [category_type_id, position] index mid-reconcile.
  def park_positions
    type.categories.order(:id).each_with_index { |category, i| category.update_columns(position: 10_000 + i) }
  end

  # Matches the clean name or the earlier "Name (examples)" label, so an option seeded
  # before descriptions had their own column is renamed in place, keeping its taggings.
  def reconcile(name, description, position)
    category = type.categories.where("LOWER(name) = LOWER(?)", name).first ||
               type.categories.where("LOWER(name) LIKE LOWER(?)", "#{name} (%").first ||
               type.categories.create!(name: name)
    category.update!(name: name, published: true, description: description)
    category.update_columns(position: position)
  end

  def unpublish_retired
    canonical = SETTINGS.map { |name, _| name.downcase }
    type.categories.reject { |category| canonical.include?(category.name.downcase) }
        .each { |category| category.update!(published: false) }
  end
end
