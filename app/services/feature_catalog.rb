require "yaml"

# Imports the checked-in feature seed (config/features.yml) into the database
# that backs the "Features & tips" page (/features). The page itself is
# admin-editable in-app; this is the starter content plus a safe way to pull in
# newly-shipped features (and fill in details) an AI/dev added to the YAML.
#
# `import!` (the "Sync latest updates" button):
#   - creates any seed feature not already in the database (matched by name), and
#   - fills in BLANK fields on existing features from the seed.
# It never overwrites a field an admin has already filled in, so syncing is safe.
# See CLAUDE.md "Features & tips page".
class FeatureCatalog
  DATA_PATH = Rails.root.join("config/features.yml")

  # Fields the sync may fill in on an existing record when they're blank. Excludes
  # name (the match key), released_on (always present), and published (a boolean,
  # which is never "blank").
  FILLABLE_FIELDS = %i[ area display_status summary pro_tips external_url action_path pr_number rhino_description ].freeze

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
      elsif (fills = blank_fills(feature, attributes)).any?
        feature.update!(fills)
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

  # The subset of seed attributes whose target column is currently blank on the
  # record — i.e. the "missing info" a sync should fill in.
  def blank_fills(feature, attributes)
    FILLABLE_FIELDS.each_with_object({}) do |field, fills|
      seed_value = attributes[field]
      next if seed_value.blank?
      next if feature.public_send(field).present?

      fills[field] = seed_value
    end
  end
end
