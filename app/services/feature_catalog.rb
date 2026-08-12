require "yaml"

# Imports the checked-in feature seed (config/features.yml) into the database
# that backs the "Features & tips" page (/features). The page itself is
# admin-editable in-app; this is the starter content plus a safe way to pull in
# newly-shipped features (and fill in details) an AI/dev added to the YAML.
#
# `import!` (the "Sync latest updates" button):
#   - creates any seed feature not already in the database (matched by name),
#   - keeps CATALOG_FIELDS (the classification the catalog owns — area, audience,
#     links, date, PR) in step with the seed on existing records, and
#   - fills in blank CONTENT_FIELDS (the admin-owned write-up — summary, tips,
#     guide link, rich description) without ever overwriting what an admin wrote.
# So a seed fix to a feature's audience/area/link propagates on the next sync,
# while an admin's screenshots and prose are left alone. See CLAUDE.md.
class FeatureCatalog
  DATA_PATH = Rails.root.join("config/features.yml")

  # Catalog-owned classification — always re-synced from the seed so corrections
  # (e.g. a wrong display_status) reach existing records.
  CATALOG_FIELDS = %i[ area display_status released_on action_path pr_number ].freeze

  # Admin-owned content — only filled in when blank, never overwritten.
  CONTENT_FIELDS = %i[ summary pro_tips external_url rhino_description ].freeze

  Result = Struct.new(:created, :updated) do
    def total = created + updated
    def any? = total.positive?
  end

  def initialize(path: DATA_PATH)
    @path = path
  end

  def import!
    created = 0
    updated = 0
    entries.each do |entry|
      attributes = attributes_for(entry)
      feature = Feature.find_by(name: attributes[:name])

      if feature.nil?
        Feature.create!(attributes)
        created += 1
      elsif (changes = sync_changes(feature, attributes)).any?
        feature.update!(changes)
        updated += 1
      end
    end
    Result.new(created, updated)
  end

  # Raw seed entries (array of hashes). Public so specs can assert the seed is
  # well-formed without touching the database.
  def entries
    YAML.safe_load_file(@path, permitted_classes: [ Date ]) || []
  end

  private

  def attributes_for(entry)
    {
      name: entry.fetch("name"),
      area: entry.fetch("area"),
      display_status: entry.fetch("display_status"),
      summary: entry.fetch("summary").to_s.strip,
      released_on: entry.fetch("released_on").to_date,
      pro_tips: Array(entry["pro_tips"]).map { |tip| tip.to_s.strip }.join("\n"),
      external_url: entry["external_url"].presence,
      action_path: entry["action_path"].presence,
      pr_number: entry["pr_number"].presence,
      published: entry.fetch("published", true),
      rhino_description: entry["description"].presence
    }
  end

  # What a sync should change on an existing record: re-align catalog-owned
  # classification with the seed, and fill in any blank admin-owned content.
  def sync_changes(feature, attributes)
    changes = {}

    CATALOG_FIELDS.each do |field|
      seed_value = attributes[field]
      next if seed_value.nil? || feature.public_send(field) == seed_value

      changes[field] = seed_value
    end

    CONTENT_FIELDS.each do |field|
      seed_value = attributes[field]
      next if seed_value.blank? || feature.public_send(field).present?

      changes[field] = seed_value
    end

    changes
  end
end
