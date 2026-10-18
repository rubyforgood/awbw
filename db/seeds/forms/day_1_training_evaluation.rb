# Day 1 AWBW Facilitator Training Evaluation, transcribed question-for-question
# from the November 2025 SurveyMonkey survey. Safe to run in a prod console:
#
#   load Rails.root.join("db/seeds/forms/day_1_training_evaluation.rb")
#
# Builds one standalone form (role general) and leaves the "Day 1 Survey"
# template the Feedback surveys callout uses untouched. Re-running rebuilds the
# questions while the form has no submissions, and stops once anyone has answered.
# Set PHOTO_CONTACT (e.g. "Jo at jo@example.org") to name who receives extra photos.

form_name = "Day 1 AWBW Facilitator Training Evaluation"
photo_contact = ENV["PHOTO_CONTACT"].presence

header = <<~HTML
  <p>Thank you for joining us for day 1 of the training! Please take a few minutes to share your perspective &amp; insights on day 1.</p>
  <p>Please note: We may share quotes from this evaluation with our stakeholders to help communicate the impact of our training. If you would prefer that we do not attach your first name (we refrain from sharing last names) to anything we share, please indicate that somewhere in your evaluation responses.</p>
HTML

part_one = <<~HTML.squish
  <u>Day 1: Part One</u>
  <ul>
    <li><strong>Triple Focus</strong> (Hands-on creative time, time to think as a facilitator, information sharing)</li>
    <li><strong>AWBW Lens on Art</strong> (Art is each moment we share &amp; hold space for each other, and our journeys. Our medium is time &amp; connection.)</li>
    <li><strong>Create, Carry Connect/Durational Art</strong> (Art is the journey of change rather than just the tangible object.)</li>
    <li><strong>Window of Time For You &amp; Those You Serve</strong> (This is your time to do whatever best serves you. No right or wrong way.)</li>
    <li><strong>Community Agreements</strong> (Intentions to support us in feeling safe to share, connected and supported.)</li>
    <li><strong>Art is Healing &amp; Healing is Art</strong> (Art is not just making something with our hands, it is also the process of healing and growing.)</li>
    <li><strong>Arc of Healing &amp; AWBW Art Workshop Structure</strong> (Intentional structure, each element building upon the next.)</li>
    <li><strong>Trauma-Informed Art Facilitation</strong> (Utilizing trauma informed practices in art workshops.)</li>
    <li><strong>Mandated Reporting &amp; Different from Art Therapy</strong> (Tips about navigating through mandated reporting requirements in workshops and how AWBW workshops are different from art therapy.)</li>
    <li><strong>Listening is Art</strong> (Focusing on listening to understand, not respond.)</li>
  </ul>
HTML

part_two = <<~HTML.squish
  <u>Day 1: Part Two</u>
  <ul>
    <li><strong>Facilitator Dashboard &amp; Manual</strong> (Contains curriculum, worksheets, resources &amp; information about creating safety with participants, working with families, etc.)</li>
    <li><strong>The 3 P's of Facilitating</strong> (Preparing yourself, preparing your materials, and preparing your participants)</li>
  </ul>
HTML

clarity = "Overall, was the information presented in a clear and concise manner?"
yes_no_other = [ "Yes", "No", "Other" ]
agreement = [ "Strongly agree", "Agree", "Neutral", "Disagree", "Strongly disagree" ]
photo_question = "We invite you to upload a photo of one of your creations if you feel comfortable doing so. " \
  "If you'd like to share additional photos, please email them to #{photo_contact || "the AWBW training team"}."

workshop_growth = [ "The Touchstone Journey", "The Creating A Safer/Braver Place", "The Take A Break, Self-Regulate" ].flat_map do |workshop|
  %w[personal professional].map do |kind|
    { name: "#{workshop} workshop supported my #{kind} growth.", type: :single_select_radio, options: agreement }
  end
end

questions = [
  { name: "Name and Agency (optional)", type: :no_user_input },
  { name: "Name", type: :free_form_input_one_line, width: :half },
  { name: "Agency", type: :free_form_input_one_line, width: :half },
  { name: clarity, type: :single_select_radio, subtitle: part_one, options: yes_no_other },
  { name: "Please elaborate.", type: :free_form_input_paragraph },
  { name: clarity, type: :single_select_radio, subtitle: part_two, options: yes_no_other },
  { name: "Please elaborate.", type: :free_form_input_paragraph },
  *workshop_growth,
  { name: "The breakout rooms supported me in sharing about my experience and connect with other trainees.", type: :single_select_radio, options: agreement },
  { name: "I was able to practice grounding and self-regulation during the training.", type: :single_select_radio, options: agreement },
  { name: "What I learned today better prepared me to facilitate art workshops.", type: :single_select_radio, options: agreement },
  { name: "What I learned today better prepared me to utilize trauma informed practices during art workshops.", type: :single_select_radio, options: agreement },
  { name: "Having time to join a breakout room to dive into one of these topics: Preparing to Facilitate, Listening is Art, Arc of Healing & Structure of an Art Workshop, Navigating Big Feelings In Art Workshops, helped me feel better prepared to facilitate.", type: :single_select_radio, options: agreement },
  { name: "Taking time to review and reflect after each workshop on how an element of the arc of healing connected to a part of the workshop structure will support me in facilitating art workshops.", type: :single_select_radio, options: agreement },
  { name: "Please tell us what aspects of day 1 of the training could be improved.", type: :free_form_input_paragraph },
  { name: "Please tell us what aspects of day 1 you enjoyed the most.", type: :free_form_input_paragraph },
  { name: "Comments", type: :free_form_input_paragraph },
  { name: "Imagine how you would share your experience of this training with someone who is considering attending. Please share in a couple of sentences what you would say or tell them.", type: :free_form_input_paragraph },
  { name: photo_question, type: :file_upload,
    subtitle: "Photos may be shared in print, on our website (public and Facilitator Dashboard), and/or on social media (including Facebook, Twitter, and Instagram). You can indicate below what information you are comfortable sharing with your photo." },
  { name: "If you uploaded a photo, we invite you to share about your creation here:", type: :free_form_input_paragraph },
  { name: "AWBW may share the following information with my photo:", type: :multi_select_checkbox,
    options: [ "My agency name", "My first name", "My first and last name", "State I'm located in", "City I'm located in" ] }
]

form = Form.standalone.find_by(name: form_name)

if form&.form_submissions&.exists?
  puts "\"#{form_name}\" (form #{form.id}) already has #{form.form_submissions.count} submission(s); leaving it untouched."
else
  ActiveRecord::Base.transaction do
    form ||= Form.create!(name: form_name, role: "general")
    form.update!(header: header, role: "general")
    form.form_fields.destroy_all

    questions.each.with_index(1) do |question, position|
      field = form.form_fields.create!(
        name: question[:name], answer_type: question[:type], position: position, required: false,
        subtitle: question[:subtitle], width: question.fetch(:width, :full), status: :active
      )
      Array(question[:options]).each_with_index do |label, index|
        option = AnswerOption.find_or_create_by!(name: label) { |new_option| new_option.position = index }
        field.form_field_answer_options.create!(answer_option: option)
      end
    end
  end

  puts "Built \"#{form_name}\" (form #{form.id}) with #{form.form_fields.count} questions."
  puts "Set PHOTO_CONTACT and re-run to name who receives extra photos." unless photo_contact
end
