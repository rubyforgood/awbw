# frozen_string_literal: true

class WorkshopFromIdeaService
	def initialize(workshop_idea, user:)
		@workshop_idea = workshop_idea
		@user = user
	end

	def call
		Workshop.new(attributes_from_idea).tap do |workshop|
			duplicate_series_children(workshop)
			duplicate_images(workshop)
		end
	end

	private

	attr_reader :workshop_idea, :user

	def attributes_from_idea
		workshop_idea.attributes.slice(
			"title", "objective", "objective_spanish",
			"materials", "materials_spanish",
			"optional_materials", "optional_materials_spanish",
			"setup", "setup_spanish",
			"introduction", "introduction_spanish",
			"demonstration", "demonstration_spanish",
			"warm_up", "warm_up_spanish",
			"creation", "creation_spanish",
			"closing", "closing_spanish",
			"opening_circle", "opening_circle_spanish",
			"notes", "notes_spanish",
			"tips", "tips_spanish",
			"windows_type_id", "age_range", "age_range_spanish",
			"visualization", "visualization_spanish",
			"extra_field", "extra_field_spanish",
			"misc1", "misc1_spanish", "misc2", "misc2_spanish",
			"time_intro", "time_closing", "time_creation",
			"time_demonstration", "time_warm_up",
			"time_opening", "time_opening_circle"
		).merge(
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

	def duplicate_images(workshop)
		workshop_idea.images.each do |image|
			workshop.images.build(file: image.file.blob)
		end
	end
end
