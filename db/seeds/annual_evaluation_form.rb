# Annual Evaluation Form Seed
# This creates the Form Builder and Form Fields for Annual Evaluations

puts "Creating Annual Evaluation Form..."

# Find or create WindowsType for combined (works for all types)
combined_type = WindowsType.find_or_create_by!(name: "ADULT & CHILDREN COMBINED (FAMILY) WINDOWS") do |wt|
  wt.legacy_id = 3
  wt.short_name = "COMBINED"
end

# Create Form Builder for Annual Evaluation
form_builder = FormBuilder.find_or_create_by!(name: "Annual Evaluation") do |fb|
  fb.windows_type = combined_type
  fb.description = "Annual Evaluation for Organizations"
end

# Create or update the Form
form = form_builder.forms.first_or_create!(owner: form_builder)

# Define form fields for Annual Evaluation
# Position numbers are in reverse order (higher number displays first)
form_fields_data = [
  {
    question: "Organization Name",
    answer_type: :free_form_input_one_line,
    answer_datatype: :text_alphanumeric,
    position: 1000,
    status: :active,
    is_required: true,
    instructional_hint: "Name of your organization"
  },
  {
    question: "Contact Person Name",
    answer_type: :free_form_input_one_line,
    answer_datatype: :text_alphanumeric,
    position: 990,
    status: :active,
    is_required: true,
    instructional_hint: "Primary contact for this evaluation"
  },
  {
    question: "Contact Email",
    answer_type: :free_form_input_one_line,
    answer_datatype: :text_alphanumeric,
    position: 980,
    status: :active,
    is_required: true,
    instructional_hint: "Email address for contact person"
  },
  {
    question: "Contact Phone Number",
    answer_type: :free_form_input_one_line,
    answer_datatype: :text_alphanumeric,
    position: 970,
    status: :active,
    is_required: false,
    instructional_hint: "Phone number for contact person"
  },
  {
    question: "Total number of participants served this year",
    answer_type: :free_form_input_one_line,
    answer_datatype: :number_integer,
    position: 960,
    status: :active,
    is_required: true,
    instructional_hint: "Approximate total number of individuals who participated in your programs"
  },
  {
    question: "Number of facilitators trained or active this year",
    answer_type: :free_form_input_one_line,
    answer_datatype: :number_integer,
    position: 950,
    status: :active,
    is_required: true,
    instructional_hint: "Total facilitators who led or were trained for workshops"
  },
  {
    question: "Total number of workshops conducted this year",
    answer_type: :free_form_input_one_line,
    answer_datatype: :number_integer,
    position: 940,
    status: :active,
    is_required: true,
    instructional_hint: "Total count of all workshops/sessions held"
  },
  {
    question: "Primary populations served",
    answer_type: :free_form_input_paragraph,
    answer_datatype: :text_alphanumeric,
    position: 930,
    status: :active,
    is_required: true,
    instructional_hint: "Describe the main groups/demographics you served (e.g., survivors of domestic violence, children in foster care, veterans)"
  },
  {
    question: "Geographic area(s) served",
    answer_type: :free_form_input_paragraph,
    answer_datatype: :text_alphanumeric,
    position: 920,
    status: :active,
    is_required: true,
    instructional_hint: "Cities, counties, or regions where services were provided"
  },
  {
    question: "What were your organization's most significant accomplishments this year?",
    answer_type: :free_form_input_paragraph,
    answer_datatype: :text_alphanumeric,
    position: 910,
    status: :active,
    is_required: true,
    instructional_hint: "Describe major achievements, milestones, or successes"
  },
  {
    question: "What challenges did your organization face this year?",
    answer_type: :free_form_input_paragraph,
    answer_datatype: :text_alphanumeric,
    position: 900,
    status: :active,
    is_required: true,
    instructional_hint: "Describe obstacles, difficulties, or areas that need improvement"
  },
  {
    question: "How has participation in the AWBW network benefited your organization?",
    answer_type: :free_form_input_paragraph,
    answer_datatype: :text_alphanumeric,
    position: 890,
    status: :active,
    is_required: true,
    instructional_hint: "Describe specific ways the AWBW network has supported your work"
  },
  {
    question: "What resources or support from AWBW would be most helpful in the coming year?",
    answer_type: :free_form_input_paragraph,
    answer_datatype: :text_alphanumeric,
    position: 880,
    status: :active,
    is_required: true,
    instructional_hint: "Identify needs, training opportunities, or resources that would benefit your organization"
  },
  {
    question: "Participant feedback/success stories",
    answer_type: :free_form_input_paragraph,
    answer_datatype: :text_alphanumeric,
    position: 870,
    status: :active,
    is_required: false,
    instructional_hint: "Share any notable quotes, testimonials, or success stories from participants (optional)"
  },
  {
    question: "Overall program quality rating",
    answer_type: :multiple_choice_radio,
    answer_datatype: :text_alphanumeric,
    position: 860,
    status: :active,
    is_required: true,
    instructional_hint: "Rate the overall quality of your Windows programs this year"
  },
  {
    question: "Plans for the coming year",
    answer_type: :free_form_input_paragraph,
    answer_datatype: :text_alphanumeric,
    position: 850,
    status: :active,
    is_required: true,
    instructional_hint: "Describe your organization's goals and plans for the upcoming year"
  },
  {
    question: "Additional comments or information",
    answer_type: :free_form_input_paragraph,
    answer_datatype: :text_alphanumeric,
    position: 840,
    status: :active,
    is_required: false,
    instructional_hint: "Any other information you'd like to share (optional)"
  }
]

# Create form fields
form_fields_data.each do |field_data|
  form_field = form.form_fields.find_or_initialize_by(question: field_data[:question])
  form_field.assign_attributes(field_data)
  form_field.save!
  puts "  Created/Updated form field: #{field_data[:question]}"
end

# Create answer options for the rating question
rating_field = form.form_fields.find_by(question: "Overall program quality rating")
if rating_field
  rating_options = [
    "Excellent",
    "Very Good",
    "Good",
    "Fair",
    "Needs Improvement"
  ]

  rating_options.each do |option_text|
    answer_option = AnswerOption.find_or_create_by!(name: option_text)
    rating_field.form_field_answer_options.find_or_create_by!(answer_option: answer_option)
    puts "    Added answer option: #{option_text}"
  end
end

puts "Annual Evaluation Form created successfully!"
puts "Form Builder ID: #{form_builder.id}"
puts "Form ID: #{form.id}"
puts "Total Form Fields: #{form.form_fields.count}"
