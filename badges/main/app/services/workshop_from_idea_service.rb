# frozen_string_literal: true

class WorkshopFromIdeaService
  def initialize(workshop_idea, user:)
    @workshop_idea = workshop_idea
    @user = user
  end

  def call
    Workshop.new(attributes_from_idea).tap do |workshop|
      duplicate_series_children(workshop)
    end
  end

  private

  attr_reader :workshop_idea, :user

  def attributes_from_idea
    workshop_idea.attributes.slice(
      "title", "windows_type_id", "age_range",
      "time_intro", "time_closing", "time_creation",
      "time_demonstration", "time_warm_up",
      "time_opening", "time_opening_circle"
    ).merge(
      rhino_objective: workshop_idea.rhino_objective,
      rhino_materials: workshop_idea.rhino_materials,
      rhino_optional_materials: workshop_idea.rhino_optional_materials,
      rhino_setup: workshop_idea.rhino_setup,
      rhino_introduction: workshop_idea.rhino_introduction,
      rhino_demonstration: workshop_idea.rhino_demonstration,
      rhino_warm_up: workshop_idea.rhino_warm_up,
      rhino_creation: workshop_idea.rhino_creation,
      rhino_closing: workshop_idea.rhino_closing,
      rhino_opening_circle: workshop_idea.rhino_opening_circle,
      rhino_notes: workshop_idea.rhino_notes,
      rhino_tips: workshop_idea.rhino_tips,
      rhino_visualization: workshop_idea.rhino_visualization,
      rhino_extra_field: workshop_idea.rhino_extra_field,
      rhino_misc1: workshop_idea.rhino_misc1,
      rhino_misc2: workshop_idea.rhino_misc2,
      rhino_objective_spanish: workshop_idea.rhino_objective_spanish,
      rhino_materials_spanish: workshop_idea.rhino_materials_spanish,
      rhino_optional_materials_spanish: workshop_idea.rhino_optional_materials_spanish,
      rhino_age_range_spanish: workshop_idea.rhino_age_range_spanish,
      rhino_setup_spanish: workshop_idea.rhino_setup_spanish,
      rhino_introduction_spanish: workshop_idea.rhino_introduction_spanish,
      rhino_opening_circle_spanish: workshop_idea.rhino_opening_circle_spanish,
      rhino_demonstration_spanish: workshop_idea.rhino_demonstration_spanish,
      rhino_warm_up_spanish: workshop_idea.rhino_warm_up_spanish,
      rhino_visualization_spanish: workshop_idea.rhino_visualization_spanish,
      rhino_creation_spanish: workshop_idea.rhino_creation_spanish,
      rhino_closing_spanish: workshop_idea.rhino_closing_spanish,
      rhino_notes_spanish: workshop_idea.rhino_notes_spanish,
      rhino_tips_spanish: workshop_idea.rhino_tips_spanish,
      rhino_misc1_spanish: workshop_idea.rhino_misc1_spanish,
      rhino_misc2_spanish: workshop_idea.rhino_misc2_spanish,
      rhino_extra_field_spanish: workshop_idea.rhino_extra_field_spanish,
      user_id: user.id,
      workshop_idea_id: workshop_idea.id,
      month: workshop_idea.created_at.month,
      year: workshop_idea.created_at.year,
      featured: false,
      inactive: true
    )
  end

  def duplicate_series_children(workshop)
    workshop.workshop_series_children.build(
      workshop_idea.workshop_series_children.map do |child|
        {
          workshop_child_id: child.workshop_child_id,
          theme_name: child.theme_name,
          series_description: child.series_description,
          series_description_spanish: child.series_description_spanish,
          series_order: child.series_order
        }
      end
    )
  end
end
