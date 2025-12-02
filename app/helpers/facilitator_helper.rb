module FacilitatorHelper

	def facilitator_profile_button(facilitator, size: 10)
		link_to facilitator_path(facilitator),
						class: "btn btn-secondary-outline flex items-center gap-3 px-4 py-2 rounded-lg" do

			facilitator = facilitator.decorate
			avatar = if facilitator.avatar_image.present?
								 image_tag url_for(facilitator.avatar_image.file),
													 class: "w-10 h-10 rounded-full object-cover border border-gray-300 shadow-sm"
							 else
								 image_tag "missing.png",
													 class: "w-10 h-10 rounded-full object-cover border border-dashed border-gray-300"
							 end

			name = content_tag(:span, facilitator.name, class: "font-semibold text-gray-900")

			pronouns = if facilitator.pronouns_display.present?
									 content_tag(:span, facilitator.pronouns_display,
															 class: "text-xs text-gray-500 italic")
								 end

			avatar + content_tag(:div, name + (pronouns || "").html_safe,
													 class: "flex flex-col leading-tight text-left")
		end
	end
end
