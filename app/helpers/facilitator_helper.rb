module FacilitatorHelper
	def facilitator_profile_button(facilitator, size: 10)
		link_to facilitator_path(facilitator),
						class: "group inline-flex items-center gap-2 px-4 py-2
                  border border-primary text-primary rounded-lg
                  hover:bg-primary hover:text-white transition-colors duration-200
                  font-medium shadow-sm leading-none whitespace-nowrap w-60" do

			facilitator = facilitator.decorate

			# --- Avatar ---
			avatar = if facilitator.avatar_image.present?
								 image_tag url_for(facilitator.avatar_image.file),
													 class: "w-10 h-10 rounded-full object-cover border border-gray-300 shadow-sm"
							 elsif facilitator.user&.avatar.present?
								 image_tag url_for(facilitator.user.avatar),
													 class: "w-10 h-10 rounded-full object-cover border border-gray-300 shadow-sm"
							 else
								 image_tag "missing.png",
													 class: "w-10 h-10 rounded-full object-cover border border-dashed border-gray-300"
							 end

			# --- Name: stays one line & turns white on hover ---
			name = content_tag(
				:span,
				facilitator.name.to_s.truncate(21),
				title: facilitator.name.to_s,
				class: "font-semibold text-gray-900 whitespace-nowrap group-hover:text-white"
			)

			# --- Pronouns ---
			pronouns = if facilitator.pronouns_display.present?
									 content_tag(
										 :span,
										 facilitator.pronouns_display,
										 class: "text-xs text-gray-500 italic group-hover:text-white"
									 )
								 end

			text_block = content_tag(
				:div,
				safe_join([name, pronouns].compact),
				class: "flex flex-col leading-tight text-left"
			)

			avatar + text_block
		end
	end


end
