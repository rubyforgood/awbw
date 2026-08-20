# Standalone public forms (dev-only).
#
# A couple of forms not connected to any event, published at their public pretty
# URL (/f/:slug), each with a few submissions + answers — so the public endpoint,
# the form editor's "Public form" card, and the form submissions index (where
# these appear as role: "public", event-less) all have real data to eyeball.
#
# Idempotent throughout: forms are looked up by slug, submissions by (form,
# person), answers skipped when already present.

puts "Creating standalone public forms…"

public_forms = [
  {
    slug: "volunteer-interest",
    name: "Volunteer interest",
    header: "Interested in volunteering with A Window Between Worlds? Tell us a little about yourself.",
    questions: [
      { name: "Why do you want to volunteer with us?", answer_type: :free_form_input_paragraph },
      { name: "What days are you generally available?", answer_type: :free_form_input_one_line }
    ],
    submissions: [
      { first_name: "Dana", last_name: "Volunteer", email: "dana.volunteer@example.com",
        answers: [ "I run art workshops for teens and want to bring AWBW's approach to my community.",
                   "Weekday evenings and Saturdays" ] },
      { first_name: "Emil", last_name: "Helper", email: "emil.helper@example.com",
        answers: [ "I'm a retired social worker looking to give back.", "Weekday mornings" ] }
    ]
  },
  {
    slug: "general-inquiry",
    name: "General inquiry",
    header: "Have a question for our team? Send it our way and we'll get back to you.",
    questions: [
      { name: "Your message", answer_type: :free_form_input_paragraph }
    ],
    submissions: [
      { first_name: "Priya", last_name: "Question", email: "priya.question@example.com",
        answers: [ "Do you offer facilitator training in the Pacific Northwest?" ] },
      { first_name: "Sam", last_name: "Inquiry", email: "sam.inquiry@example.com",
        answers: [ "How can our shelter partner with AWBW?" ] },
      { first_name: "Alex", last_name: "Reachout", email: "alex.reachout@example.com",
        answers: [ "Requesting a media kit for an upcoming article." ] }
    ]
  }
]

public_forms.each do |spec|
  form = Form.standalone.find_by(slug: spec[:slug])
  unless form
    form = FormBuilderService.new(name: spec[:name], sections: %i[person_identifier]).call
    form.update!(slug: spec[:slug], published: true, header: spec[:header])
  end

  question_fields = spec[:questions].map do |question|
    form.form_fields.find_by(name: question[:name]) ||
      form.form_fields.create!(name: question[:name], answer_type: question[:answer_type], status: :active)
  end

  spec[:submissions].each do |data|
    person = Person.find_or_create_by!(email: data[:email]) do |p|
      p.first_name = data[:first_name]
      p.last_name = data[:last_name]
    end

    submission = FormSubmission.find_or_create_by!(form: form, person: person, role: "public")

    identity = {
      "first_name" => data[:first_name],
      "last_name" => data[:last_name],
      "primary_email" => data[:email]
    }
    question_answers = question_fields.zip(data[:answers]).to_h

    identity.each do |identifier, value|
      field = form.form_fields.find_by(field_identifier: identifier)
      next unless field
      next if submission.form_answers.where(form_field: field).any?
      submission.form_answers.create!(form_field: field, submitted_answer: value,
                                      question_name_when_answered: field.name)
    end

    question_answers.each do |field, value|
      next if value.blank? || submission.form_answers.where(form_field: field).any?
      submission.form_answers.create!(form_field: field, submitted_answer: value,
                                      question_name_when_answered: field.name)
    end
  end
end
