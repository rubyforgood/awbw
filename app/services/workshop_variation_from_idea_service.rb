# frozen_string_literal: true

class WorkshopVariationFromIdeaService
  def initialize(workshop_variation_idea, user:)
    @workshop_variation_idea = workshop_variation_idea
    @user = user
  end

  def call
    WorkshopVariation.new(attributes_from_idea)
  end

  private

  attr_reader :workshop_variation_idea, :user

  def attributes_from_idea
    workshop_variation_idea.attributes.slice(
      "name", "youtube_url", "position", "workshop_id", "windows_type_id", "organization_id", "author_credit_preference"
    ).merge(
      created_by_id: user.id,
      author_id: workshop_variation_idea.created_by&.person_id,
      workshop_variation_idea_id: workshop_variation_idea.id,
      inactive: true,
      rhino_body: workshop_variation_idea.rhino_body
    )
  end
end
