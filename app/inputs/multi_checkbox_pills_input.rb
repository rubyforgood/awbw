class MultiCheckboxPillsInput < SimpleForm::Inputs::CollectionCheckBoxesInput
	def input(wrapper_options = nil)
		merged_input_options = merge_wrapper_options(input_html_options, wrapper_options)

		# Build each checkbox wrapped in a label with Tailwind "pill" styles
		@builder.collection_check_boxes(attribute_name, collection, :last, :first, merged_input_options) do |b|
			b.label(class: "cursor-pointer") do
				b.check_box(class: "hidden peer") +
					template.content_tag(:span,
															 b.text,
															 class: "inline-block px-3 py-1 rounded-full border border-gray-300 bg-white text-gray-700
                                    hover:bg-blue-100 peer-checked:bg-blue-600 peer-checked:text-white transition")
			end
		end.join.html_safe
	end
end