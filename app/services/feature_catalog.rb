require "yaml"

# Imports the checked-in feature seed (config/features.yml) into the database
# that backs the public "Features & tips" page (/features). The page itself is
# admin-editable in-app; this is only the starter content plus a safe way to pull
# in newly-shipped features an AI/dev appended to the YAML.
#
# `import!` is CREATE-MISSING-ONLY (matched by name): it never overwrites an
# existing Feature, so hydrating from the seed can't clobber an admin's in-app
# edits. See CLAUDE.md "Features & tips page".
class FeatureCatalog
  DATA_PATH = Rails.root.join("config/features.yml")

  def initialize(path: DATA_PATH)
    @path = path
  end

  # Creates any seed feature not already in the database. Returns the number
  # created (0 when everything is already present).
  def import!
    created = 0
    entries.each do |entry|
      name = entry.fetch("name")
      next if Feature.exists?(name: name)

      Feature.create!(
        name: name,
        area: entry.fetch("area"),
        display_status: entry.fetch("display_status"),
        summary: entry.fetch("summary").to_s.strip,
        released_on: entry.fetch("released_on").to_date,
        pro_tips: Array(entry["pro_tips"]).map { |tip| tip.to_s.strip }.join("\n"),
        external_url: entry["external_url"].presence,
        published: entry.fetch("published", true),
        rhino_description: entry["description"].presence
      )
      created += 1
    end
    created
  end

  # Raw seed entries (array of hashes). Public so specs can assert the seed is
  # well-formed without touching the database.
  def entries
    YAML.safe_load_file(@path, permitted_classes: [ Date ]) || []
  end
end
