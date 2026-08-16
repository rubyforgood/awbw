require "yaml"

# Syncs the checked-in feature seed (config/features.yml) into the DB behind the
# "Features & tips" page. `import!` (the "Sync latest updates" button) creates
# missing features and, on existing ones, re-syncs CATALOG_FIELDS from the seed
# while only filling BLANK CONTENT_FIELDS — so a seed fix to a feature's
# classification propagates, but an admin's prose/screenshots are never
# overwritten. See CLAUDE.md.
class FeatureCatalog
  DATA_PATH = Rails.root.join("config/features.yml")

  # Catalog-owned classification — always re-synced so seed corrections reach
  # existing records.
  CATALOG_FIELDS = %i[ area display_status released_on action_path pr_number ].freeze

  # Admin-owned content — only filled when blank, never overwritten.
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
