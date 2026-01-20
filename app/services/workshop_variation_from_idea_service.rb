# frozen_string_literal: true

class WorkshopVariationFromIdeaService
  def initialize(workshop_variation_idea, user:)
    @workshop_variation_idea = workshop_variation_idea
    @user = user
  end

  def call
    WorkshopVariation.new(attributes_from_idea).tap do |workshop_variation|
      duplicate_assets(workshop_variation)
    end
  end

  private

  attr_reader :workshop_variation_idea, :user

  def attributes_from_idea
    workshop_variation_idea.attributes.slice(
      "name", "description", "youtube_url",
      "position", "workshop_id"
    ).merge(
      created_by_id: user.id,
      workshop_variation_idea_id: workshop_variation_idea.id,
      inactive: true
    )
  end

  def duplicate_assets(workshop_variation)
    workshop_variation_idea.assets.each do |asset|
      workshop_variation.assets.build(file: asset.file.blob)
    end
  end
end
