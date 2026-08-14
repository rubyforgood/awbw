json.id story.id
json.slug story.to_param
json.title story.title
json.body story.rhino_body.to_plain_text
json.url story_url(story)

json.featured story.featured
json.publicly_featured story.publicly_featured
json.published story.published

json.website_url story.website_url
json.youtube_url story.youtube_url

# Credited author, honoring the story's privacy preference (may be "Anonymous").
json.author story.author_credit

json.organization do
  json.name story.organization_name
  json.locality story.organization_locality
end

json.windows_type story.windows_type&.name
json.sectors story.sector_names_all
json.audience_categories story.audience_categories.pluck(:name)

if story.primary_asset&.file&.attached?
  json.image_url rails_blob_url(story.primary_asset.file)
  json.thumbnail_url rails_representation_url(story.primary_asset.file.variant(:thumbnail))
else
  json.image_url nil
  json.thumbnail_url nil
end

json.created_at story.created_at.iso8601
json.updated_at story.updated_at.iso8601
