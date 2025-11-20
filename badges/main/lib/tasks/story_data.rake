namespace :story_data do
	desc "Generate Stories from Resources"
	task generate_stories_from_resources: :environment do
		puts "🚀 Starting Story creation for all Resources of type Story..."
		puts "Environment: #{Rails.env}"
		puts "==============================================="
		default_user_id = User.first&.id || 1

		Resource.where(kind: "Story").find_each do |resource|
			Story.where(title:                 resource.title,)
					 .first_or_create!(
				body:                  resource.text,
				created_by_id:         resource.user_id || default_user_id,
				updated_by_id:         resource.user_id || default_user_id,
				featured:              resource.featured,
				permission_given:      true,
				project_id:            nil, # resources don't store this, add mapping if needed
				published:             !resource.inactive,
				spotlighted_facilitator_id: nil,
				story_idea_id:         nil,
				website_url:           resource.url,
				windows_type_id:       resource.windows_type_id || WindowsType.first&.id,
				workshop_id:           resource.workshop_id,
				youtube_url:           nil, # resources don't store this, add mapping if needed
				created_at:            resource.created_at,
				updated_at:            resource.updated_at
			)
		end
	end
end
