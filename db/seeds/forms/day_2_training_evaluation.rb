# Day 2 AWBW Facilitator Training Evaluation, transcribed question-for-question
# from the November 2025 SurveyMonkey survey. Safe to run in a prod console:
#
#   load Rails.root.join("db/seeds/forms/day_2_training_evaluation.rb")
#
# Builds the day_2_survey form the Feedback surveys callout delivers, rebuilding
# the seeded template in place. Re-running rebuilds the questions while the form
# has no submissions, and stops once anyone has answered.
# Set PHOTO_CONTACT (e.g. "Jo at jo@example.org") to name who receives extra photos.

role = "day_2_survey"
photo_contact = ENV["PHOTO_CONTACT"].presence

header = <<~HTML
  <p>Congratulations on completing the training! We enjoyed creating and learning together. Please take some time to share your perspective and insights on day 2.</p>
  <p>Please note: We may share quotes from this evaluation with our stakeholders to help communicate the impact of our training. If you would prefer that we do not attach your first name (we refrain from sharing last names) to anything we share, please indicate that somewhere in your evaluation responses.</p>
HTML

part_one = <<~HTML.squish
  <u>Day 2: Part 1 Agenda</u>
  <ul>
    <li><strong>Community of Support</strong> (On-going benefits you'll receive as a Certified member of the AWBW community of art facilitators. Including the bi-monthly email newsletter, embodied art curriculum, art workshop series &amp; more.)</li>
    <li><strong>Facilitator Resources</strong> (Resources available to share stories &amp; art from participants. As well as AWBW collaboration agreement &amp; annual fees.)</li>
    <li><strong>Training Other Staff</strong> (Information about how fellow staff can become Certified art facilitators via the AWBW On-Demand Training at a discounted rate.)</li>
    <li><strong>Art Supplies</strong> (Information about various art supplies, where to buy them, and code to get them at a discounted price. Info and playlists for playing music during art workshops).</li>
    <li><strong>From &amp; Towards Animals</strong> (Hands-on embodied art activity)</li>
    <li><strong>Intersectionality</strong> (Presentation about what it is and how to facilitate through an intersectional lens that honors all aspects of participants' identities. As well as information, resources, and curriculum on that and related topics.)</li>
  </ul>
HTML

part_two = <<~HTML.squish
  <u>Day 2: Part 2 Agenda</u>
  <ul>
    <li><strong>Addressing Questions &amp; Challenges</strong> (Sharing questions and challenges related to facilitating art workshops, then exploring some of them together as a group.)</li>
  </ul>
HTML

clarity = "Overall, was the information presented in a clear and concise manner?"
yes_no_other = [ "Yes", "No", "Other" ]
agreement = [ "Strongly agree", "Agree", "Neutral", "Disagree", "Strongly disagree" ]
photo_question = "We invite you to upload a photo of one of your creations if you feel comfortable doing so. " \
  "If you'd like to share additional photos, please email them to #{photo_contact || "the AWBW training team"}."

workshop_growth = [ "The Monster In Me", "The Claiming Who I Am" ].flat_map do |workshop|
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
  { name: "What I learned today better prepared me to facilitate art workshops that honor intersectionality.", type: :single_select_radio, options: agreement },
  { name: "Having time to dive into topics related to questions and challenges helped me feel more prepared to facilitate art workshops.", type: :single_select_radio, options: agreement },
  { name: "Taking time to review and reflect after each workshop on how an element of the arc of healing connected to a part of the workshop structure will support me in facilitating art workshops.", type: :single_select_radio, options: agreement },
  { name: "To best prepare art workshop participants to create, I understand the importance of providing a warm-up (for example: discussion, relaxation, visualization, grounding/breathing/journaling exercise, etc.) before the creation portion of the art workshop.", type: :single_select_radio, options: yes_no_other },
  { name: "Please tell us what aspects of day 2 of the training could be improved.", type: :free_form_input_paragraph },
  { name: "Please tell us what aspects of day 2 of the training you enjoyed the most.", type: :free_form_input_paragraph },
  { name: "Would you like your name and email address included on a list we will share with your fellow trainees (for those who would like to stay in touch)?", type: :single_select_radio, options: [ "Yes", "No" ] },
  { name: "How can we better support your needs and those of your art workshop participants?", type: :free_form_input_paragraph },
  { name: "Comments", type: :free_form_input_paragraph },
  { name: "Imagine how you would share your experience of this training with someone who is considering attending. Please share in a couple of sentences what you would say or tell them.", type: :free_form_input_paragraph },
  { name: photo_question, type: :file_upload,
    subtitle: "Photos may be shared in print, on our website (public and Facilitator Dashboard), and/or on social media (including Facebook, Twitter, and Instagram). You can indicate below what information you are comfortable sharing with your photo." },
  { name: "If you uploaded a photo, we invite you to share about your creation here:", type: :free_form_input_paragraph },
  { name: "AWBW may share the following information with my photo:", type: :multi_select_checkbox,
    options: [ "My agency name", "My first name", "My first and last name", "State I'm located in", "City I'm located in" ] }
]

form = Form.survey(role)

if form&.form_submissions&.exists?
  puts "\"#{form.name}\" (form #{form.id}) already has #{form.form_submissions.count} submission(s); leaving it untouched."
else
  ActiveRecord::Base.transaction do
    form ||= Form.create!(name: "Day 2 Survey", role:)
    form.update!(header:)
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

  puts "Built \"#{form.name}\" (form #{form.id}) with #{form.form_fields.count} questions."
  puts "Set PHOTO_CONTACT and re-run to name who receives extra photos." unless photo_contact
end
