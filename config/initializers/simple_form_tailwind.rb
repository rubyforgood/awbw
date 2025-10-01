# frozen_string_literal: true

SimpleForm.setup do |config|
  # Default button class
  config.button_class = "px-4 py-2 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 focus:ring focus:ring-blue-300 focus:outline-none"

  # Default wrapper for Tailwind
  config.wrappers :tailwind_form, class: "mb-4" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly

    # Label
    b.use :label, class: "block font-medium mb-1 text-gray-700"

    # Input
    b.use :input,
          class: "w-full rounded-lg border border-gray-300 px-3 py-2 text-gray-800 shadow-sm focus:border-blue-500 focus:ring focus:ring-blue-200 focus:outline-none",
          error_class: "border-red-500",
          valid_class: "border-green-500"

    # Full error message
    b.use :full_error, wrap_with: { tag: :p, class: "text-red-500 text-sm mt-1" }

    # Hint text
    b.use :hint, wrap_with: { tag: :p, class: "text-gray-500 text-sm mt-1" }
  end

  # Boolean fields
  config.wrappers :tailwind_boolean, tag: 'fieldset', class: "mb-4" do |b|
    b.use :html5
    b.optional :readonly

    b.wrapper :checkbox_wrapper, class: "flex flex-col" do |bb|
      # Wrap input and label together
      bb.wrapper :input_label, tag: :label, class: "flex items-center gap-2 cursor-pointer" do |lbl|
        lbl.use :input, class: "rounded border-gray-300 text-blue-600 focus:ring focus:ring-blue-200", error_class: "border-red-500"
        lbl.use :label_text, class: "text-gray-700 font-medium"
      end

      # Error and hint below the checkbox
      bb.use :full_error, wrap_with: { tag: :p, class: "text-red-500 text-sm mt-1" }
      bb.use :hint, wrap_with: { tag: :p, class: "text-gray-500 text-sm mt-1" }
    end
  end

  # File input
  config.wrappers :tailwind_file, class: "mb-4" do |b|
    b.use :html5
    b.optional :readonly
    b.use :label, class: "block mb-1 font-medium text-gray-700"
    b.use :input, class: "file-input w-full text-gray-700 px-3 py-2 border border-gray-300 rounded-lg cursor-pointer hover:border-gray-400"
    b.use :full_error, wrap_with: { tag: :p, class: "text-red-500 text-sm mt-1" }
    b.use :hint, wrap_with: { tag: :p, class: "text-gray-500 text-sm mt-1" }
  end


  config.wrappers :tailwind_multi_select, class: 'mb-4' do |b|
    b.use :html5
    b.optional :readonly

    b.use :label, class: 'block font-medium mb-1 text-gray-700'

    # Input wrapper
    b.wrapper :input_wrapper, class: 'relative' do |ba|
      ba.use :input,
             class: 'w-full rounded border border-gray-300 p-2 focus:ring focus:ring-blue-300 focus:border-blue-500',
             error_class: 'border-red-500',
             valid_class: 'border-green-500',
             multiple: true

      # Full error below the input
      ba.use :full_error, wrap_with: { tag: :p, class: 'text-red-500 text-sm mt-1' }
      ba.use :hint, wrap_with: { tag: :p, class: 'text-gray-500 text-sm mt-1' }
    end
  end

  # Default wrapper
  config.default_wrapper = :tailwind_form

  # Wrapper mappings
  config.wrapper_mappings = {
    boolean: :tailwind_boolean,
    check_boxes: :tailwind_boolean,
    radio_buttons: :tailwind_boolean,
    file: :tailwind_file,
    select: :tailwind_form,
    range: :tailwind_form
  }
end
