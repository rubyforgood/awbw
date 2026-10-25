require "yaml"

# Syncs the seed files in db/seeds/features/ (one per feature) into the DB behind
# /features. `import!` creates missing features and overwrites SYNCED_FIELDS on a
# same-name feature from its seed. A feature edited in-app (Feature#edited?) is
# left entirely alone.
class FeatureCatalog
  DATA_DIR = Rails.root.join("db/seeds/features")
  RECENT_SEEDS = 20

  SYNCED_FIELDS = %i[
    area display_status released_on action_path pr_number
    summary pro_tips external_url rhino_description
  ].freeze

  Result = Struct.new(:created, :updated, :skipped) do
    def total = created + updated
    def any? = total.positive?
  end

  def initialize(dir: DATA_DIR)
    @dir = dir
  end

  def import!
    created = 0
    updated = 0
    skipped = 0
    seeds = entries.map { |entry| attributes_for(entry) }
    existing = existing_features(seeds.map { |attributes| attributes[:name] })
    # Sync writes leave updated_at alone so they never register as an in-app edit.
    Feature.no_touching do
      seeds.each do |attributes|
        feature = existing[attributes[:name].downcase]

        if feature.nil?
          Feature.create!(attributes)
          created += 1
        elsif (changes = sync_changes(feature, attributes)).none?
          next
        elsif feature.edited?
          skipped += 1
        else
          feature.assign_attributes(changes)
          feature.save!(touch: false)
          updated += 1
        end
      end
    end
    Result.new(created, updated, skipped)
  end

  # Reads only the newest seeds, so a backdated seed merged after a sync waits for a newer one to flag it.
  def recent_missing?(limit: RECENT_SEEDS)
    names = seed_paths.last(limit).map { |path| load_seed(path).fetch("name") }
    existing = Feature.where(name: names).pluck(:name).to_set(&:downcase)
    names.any? { |name| existing.exclude?(name.downcase) }
  end

  def entries
    seed_paths.map { |path| load_seed(path) }
  end

  private

  def seed_paths = Dir[File.join(@dir, "*.yml")].sort

  def load_seed(path) = YAML.safe_load_file(path, permitted_classes: [ Date ])

  # Keyed by downcased name to match the case-insensitive column collation.
  def existing_features(names)
    Feature.with_rich_text_rhino_description.where(name: names).index_by { |feature| feature.name.downcase }
  end

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
    SYNCED_FIELDS.each_with_object({}) do |field, changes|
      seed_value = attributes[field]
      next if seed_value.blank? || same_value?(feature, field, seed_value)

      changes[field] = seed_value
    end
  end

  # Rich text is compared as rendered HTML, so the stored copy of an unchanged seed matches it.
  def same_value?(feature, field, seed_value)
    return feature.public_send(field) == seed_value unless field == :rhino_description

    feature.rhino_description&.body&.to_html == ActionText::Content.new(seed_value).to_html
  end
end
