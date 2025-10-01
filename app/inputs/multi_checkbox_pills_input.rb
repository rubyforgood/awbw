# app/inputs/multi_checkbox_pills_input.rb
class MultiCheckboxPillsInput < SimpleForm::Inputs::CollectionCheckBoxesInput
	def input(wrapper_options = nil)
		merged_input_options = merge_wrapper_options(input_html_options, wrapper_options)

		# Main pills input
		input_html = @builder.collection_check_boxes(attribute_name, collection, :last, :first, merged_input_options) do |b|
			b.label(class: "cursor-pointer inline-block") do
				b.check_box(class: "hidden peer") +
					template.content_tag(
						:span,
						b.text,
						class: "inline-block px-3 py-1 rounded-full border border-gray-300 bg-white text-gray-700 hover:bg-blue-100 peer-checked:bg-blue-600 peer-checked:text-white transition"
					)
			end
		end

		# Wrap input with errors and hint
		template.content_tag(:div, class: "mb-4") do
			input_html +
				# full_error returns an array of errors for this attribute
				Array(@builder.full_error(attribute_name)).join.html_safe.then do |errors|
					template.content_tag(:p, errors, class: "text-red-500 text-sm mt-1") unless errors.blank?
				end.to_s.html_safe +
				# hint from options
				if @builder.options[:hint].present?
					template.content_tag(:p, @builder.options[:hint], class: "text-gray-500 text-sm mt-1")
				else
					"".html_safe
				end
		end
	end
end
