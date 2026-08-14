json.title story.title

# Credited author, honoring the story's privacy preference (may be "Anonymous").
json.author story.author_credit

json.organization do
  json.name story.organization_name
  json.locality story.organization_locality
end

json.url story_url(story)

# Tags applied to the story: the windows type, categories (grouped by category
# type, e.g. "Age range", "Story category"), and sectors.
json.tags do
  json.windows_type story.windows_type&.name
  # Always emit `categories` as an object (`{}` when untagged) so consumers can
  # iterate it unconditionally.
  json.categories story.categories
    .group_by { |c| c.category_type&.display_label || "Other" }
    .transform_values { |cats| cats.map(&:name).sort }
  json.sectors story.sector_names_all
end

json.body story.rhino_body.to_plain_text

if story.primary_asset&.file&.attached?
  json.image_url rails_blob_url(story.primary_asset.file)
  json.thumbnail_url rails_representation_url(story.primary_asset.file.variant(:thumbnail))
else
  json.image_url nil
  json.thumbnail_url nil
end

json.created_at story.created_at.iso8601
json.updated_at story.updated_at.iso8601
