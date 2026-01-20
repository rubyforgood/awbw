# frozen_string_literal: true

class StoryFromIdeaService
  def initialize(story_idea, user:)
    @story_idea = story_idea
    @user = user
  end

  def call
    Story.new(attributes_from_idea).tap do |story|
      duplicate_assets(story)
    end
  end

  private

  attr_reader :story_idea, :user

  def attributes_from_idea
    story_idea.attributes.slice(
      "title", "body", "youtube_url",
      "windows_type_id", "project_id", "workshop_id", "external_workshop_title"
    ).merge(
      created_by_id: user.id,
      updated_by_id: user.id,
      story_idea_id: story_idea.id,
      published: false
    )
  end

  def duplicate_assets(story)
    # Duplicate primary asset with correct type
    if story_idea.primary_asset&.file&.attached?
      story.build_primary_asset(file: story_idea.primary_asset.file.blob)
    end

    # Duplicate gallery assets with correct type
    story_idea.gallery_assets.each do |gallery_asset|
      next unless gallery_asset.file&.attached?

      story.gallery_assets.build(file: gallery_asset.file.blob)
    end
  end
end
