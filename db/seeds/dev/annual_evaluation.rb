# Annual Evaluation form (dev-only).
#
# Seeds the AWBW Annual Evaluation as one standalone, published form — the full
# SurveyMonkey questionnaire (about you, your work, yearly reach, impact ratings,
# participant demographics, program impact on you, spread-the-word), plus ~20
# varied submissions so /forms/:id/results has a real report to show.
#
# Percentage and count questions are number fields (input_type number_integer),
# so the results page rolls them up as average/total/responses. Once the slider
# answer type ships, the percentage questions can switch to sliders — the stored
# values and the rollup are identical either way.
#
# Idempotent: the form is looked up by slug, fields by name, submissions by
# (form, person), and each answer is skipped when already present. Distributions
# are index-driven (no randomness) so reseeding is stable.

puts "Creating the Annual Evaluation form…"

INTRO = <<~TEXT.freeze
  Thank you for being a valued member of our Community of Practice!

  As outlined in your Collaboration Agreement, your feedback is crucial for helping us tailor our support and meet funding requirements. We appreciate the insights you provide, including those from new facilitators.

  We kindly ask that you complete your evaluation on or before December 31st. It should take approximately 20 minutes of your time. We appreciate you!
TEXT

IMPACT_SCALE = [ "Strongly agree", "Agree", "No change/not sure", "Disagree", "Strongly disagree", "N/A" ].freeze
EFFECTIVENESS = [ "Extremely effective", "Very effective", "Somewhat effective", "Not so effective", "Not at all effective" ].freeze
WORK_PERSONAL = [ "Work", "Personal" ].freeze
YES_NO = [ "Yes", "No" ].freeze

form = Form.standalone.find_by(slug: "annual-evaluation-2026")
form ||= Form.create!(name: "Annual Evaluation 2026", slug: "annual-evaluation-2026", published: true, header: INTRO)

@position = 0
@seeded_field_ids = []

# Idempotent AND convergent: an existing field (matched by name) is updated to the
# current definition, so re-running the seed picks up layout/type tweaks. Fields
# no longer defined here are pruned at the end (see below).
def ae_field!(form, name, answer_type, options: [], field_identifier: nil, input_type: nil, required: false, subtitle: nil, hint_text: nil, visibility: :always_ask, width: :full)
  @position += 1
  attrs = { name: name, answer_type: answer_type, position: @position, status: :active, required: required,
            field_identifier: field_identifier, input_type: input_type, subtitle: subtitle,
            hint_text: hint_text, visibility: visibility, width: width }
  # Match on field_identifier first (stable across a rename), else on name.
  field = (form.form_fields.find_by(field_identifier: field_identifier) if field_identifier.present?)
  field ||= form.form_fields.find_by(name: name)
  field ? field.update!(**attrs) : field = form.form_fields.create!(**attrs)
  @seeded_field_ids << field.id
  options.each_with_index do |option_name, index|
    answer_option = AnswerOption.find_or_create_by!(name: option_name) { |ao| ao.position = index + 1 }
    FormFieldAnswerOption.find_or_create_by!(form_field: field, answer_option: answer_option)
  end
  field
end

def ae_header!(form, name, subtitle: nil)
  ae_field!(form, name, :group_header, required: false, subtitle: subtitle)
end

def ae_number!(form, name, **opts)
  ae_field!(form, name, :free_form_input_one_line, input_type: :number_integer, **opts)
end

# ── About you ────────────────────────────────────────────────────────────────
# First/last name and primary email are the person-identity fields: they save to
# the Person (by field_identifier) and are logged_out_only, so once prefill lands
# a signed-in facilitator won't be re-asked for what we already have.
ae_header!(form, "About you")
first_name_field = ae_field!(form, "First name", :free_form_input_one_line, required: true,
  field_identifier: "first_name", visibility: :logged_out_only, width: :third)
last_name_field = ae_field!(form, "Last name", :free_form_input_one_line, required: true,
  field_identifier: "last_name", visibility: :logged_out_only, width: :third)
pronouns_field = ae_field!(form, "Pronouns", :free_form_input_one_line, field_identifier: "pronouns",
  hint_text: "This helps us understand the correct way to address you.", width: :third)
primary_email = ae_field!(form, "Primary Email Address", :free_form_input_one_line, required: true,
  field_identifier: "primary_email", visibility: :logged_out_only, width: :half)
primary_email_type = ae_field!(form, "Primary Email Address Type", :single_select_radio, required: true, width: :half, options: WORK_PERSONAL)
ae_field!(form, "Secondary Email Address", :free_form_input_one_line, field_identifier: "secondary_email", width: :half)
ae_field!(form, "Secondary Email Address Type", :single_select_radio, width: :half, options: WORK_PERSONAL)

# ── Organization information ─────────────────────────────────────────────────
# Named and identified like the registration form's Organization Information
# section, so these answers resolve to the facilitator's Organization.
ae_header!(form, "Organization information")
organization_field = ae_field!(form, "Organization Name", :free_form_input_one_line, required: true, width: :half,
  field_identifier: "organization_name",
  hint_text: "If you're not associated with an organization, please provide the name of your art program.")
position_title = ae_field!(form, "Position / Title", :free_form_input_one_line, required: true, width: :half,
  field_identifier: "organization_position")
ae_field!(form, "Organization Website", :free_form_input_one_line, required: true, field_identifier: "organization_website")

# ── Academic credentials ─────────────────────────────────────────────────────
# The CE-callout license fields, identified so they save to the facilitator's
# ProfessionalLicense once standalone submissions persist participant data.
ae_header!(form, "Academic credentials (if applicable)",
  subtitle: "If you hold a professional license, share it here.")
license_kind_field = ae_field!(form, "License type", :free_form_input_one_line, width: :quarter,
  field_identifier: "ce_license_kind", hint_text: "e.g. LMFT, LCSW, LPCC, MA Ed.")
ae_field!(form, "License number", :free_form_input_one_line, width: :quarter, field_identifier: "ce_license_number")
ae_field!(form, "State license was issued", :free_form_input_one_line, width: :quarter, field_identifier: "ce_license_issuing_state")
ae_field!(form, "License expiration date", :free_form_input_one_line, width: :quarter, field_identifier: "ce_license_expires_on", input_type: :date)

# ── Your work ────────────────────────────────────────────────────────────────
ae_header!(form, "Your work")
outside_us = ae_field!(form, "Do you offer art workshops outside the United States?", :single_select_radio, required: true, width: :half, options: YES_NO)
ae_field!(form, "If you offer outside the US, please share which countries", :free_form_input_one_line, width: :half)
other_language = ae_field!(form, "Do you facilitate art workshops in languages other than English?", :single_select_radio, required: true, width: :half, options: YES_NO)
ae_field!(form, "If you offer in other languages, please share which ones", :free_form_input_one_line, width: :half)
pct_one_on_one = ae_number!(form, "What percentage of your art workshops are one-on-one?", hint_text: "0–100%", width: :half)
pct_groups = ae_number!(form, "What percentage of your art workshops are with groups?", hint_text: "0–100%", width: :half)
ae_field!(form, "How else do you use art beyond direct client work?", :multi_select_checkbox,
  subtitle: "Select all that apply.",
  options: [
    "For strengthening self-care practices",
    "With staff or colleagues (staff meetings, team building, strengthening community care practices, etc.)",
    "Sharing participant artwork with donors or community stakeholders",
    "With organizational or community leaders (boards, advisory boards, etc.)",
    "Community outreach events",
    "Other"
  ])

# ── Your individual yearly reach ─────────────────────────────────────────────
ae_header!(form, "Your individual yearly reach",
  subtitle: "Please provide the estimated total number of unduplicated individuals you personally served through AWBW workshops this year. Count each participant only once. Please include fellow staff, family, and friends you facilitated with.")
reach_children = ae_number!(form, "Children (ages 0-12)", required: true, width: :quarter)
reach_teens = ae_number!(form, "Teens (ages 13-17)", required: true, width: :quarter)
reach_adults = ae_number!(form, "Adults (age 18-64)", required: true, width: :quarter)
reach_elders = ae_number!(form, "Elders (age 65+)", required: true, width: :quarter)
pct_families = ae_number!(form, "What percentage of participants consists of families of two or more individuals?", required: true,
  subtitle: "Family relationships can include parents, children, siblings, grandparents, aunts, uncles, and more.")
# Dynamic field: options come from the AgeRange categories and the answer resolves
# to the facilitator's primary age group, exactly like the registration form.
primary_age = ae_field!(form, "What is the primary age group you serve through art workshops?", :single_select_dropdown, required: true,
  field_identifier: "primary_age_group",
  subtitle: "Select the age group you primarily serve.")

# ── Measuring impact: how does art help? ─────────────────────────────────────
ae_header!(form, "Measuring impact: how does art help?",
  subtitle: "Please rate the impact of art workshops based on your personal observations of participants' experience this year.")
impact_future = ae_field!(form, "The art workshops helped participants feel more positive about their future.", :single_select_dropdown, required: true, options: IMPACT_SCALE)
impact_resilience = ae_field!(form, "The art workshops helped participants build resilience.", :single_select_dropdown, required: true, options: IMPACT_SCALE)
ae_field!(form, "The art workshops helped build and improve adult-child relationships.", :single_select_dropdown, required: true, options: IMPACT_SCALE)
ae_field!(form, "The art workshops helped build and improve relationships between participants and others in their lives.", :single_select_dropdown, required: true, options: IMPACT_SCALE)
ae_field!(form, "The art workshops helped participants build a sense of self-efficacy and agency.", :single_select_dropdown, required: true, options: IMPACT_SCALE)
ae_field!(form, "The art workshops helped participants strengthen adaptive skills and self-regulatory capacities.", :single_select_dropdown, required: true, options: IMPACT_SCALE)
without_awbw = ae_field!(form, "Would you or your organization have an art program without the support of AWBW?", :single_select_radio, required: true, options: YES_NO)

# ── Your art workshop participants (ethnicity) ───────────────────────────────
ae_header!(form, "Your art workshop participants",
  subtitle: "What percentage of your participants are from the following ethnic backgrounds? Your total allocation across all ethnic backgrounds should add up to 100%. Please use your best estimations.")
pct_alaskan = ae_number!(form, "What percentage of your participants are Alaskan Native?", hint_text: "0–100%", width: :third)
ae_number!(form, "What percentage of your participants are American Indian or Native American?", hint_text: "0–100%", width: :third)
pct_asian = ae_number!(form, "What percentage of your participants are Asian?", hint_text: "0–100%", width: :third)
pct_black = ae_number!(form, "What percentage of your participants are Black or African American?", hint_text: "0–100%", width: :third)
pct_latinx = ae_number!(form, "What percentage of your participants are Latinx?", hint_text: "0–100%", width: :third)
ae_number!(form, "What percentage of your participants are Middle Eastern?", hint_text: "0–100%", width: :third)
ae_number!(form, "What percentage of your participants are multi-racial?", hint_text: "0–100%", width: :third)
ae_number!(form, "What percentage of your participants are Native Hawaiian or other Pacific Islander?", hint_text: "0–100%", width: :third)
pct_white = ae_number!(form, "What percentage of your participants are White?", hint_text: "0–100%", width: :third)
ae_number!(form, "What percentage of your participants are of an ethnicity not listed above?", hint_text: "0–100%", width: :half)
ae_field!(form, "For participants whose ethnic identities are not listed above, please specify their ethnicities", :free_form_input_paragraph, width: :half)
pct_poverty = ae_number!(form, "What percentage of your participants are at or below the Federal Poverty Line?",
  hint_text: "See the current Federal Poverty Level Guidelines. 0–100%")

# ── Participant gender identity ──────────────────────────────────────────────
ae_header!(form, "Participant gender identity",
  subtitle: "What percentage of your participants identify as the following? Please use your best estimations.")
pct_female = ae_number!(form, "What percentage of your participants identify as female?", hint_text: "0–100%", width: :quarter)
pct_male = ae_number!(form, "What percentage of your participants identify as male?", hint_text: "0–100%", width: :quarter)
ae_number!(form, "What percentage of your participants identify as non-binary?", hint_text: "0–100%", width: :quarter)
ae_number!(form, "What percentage of your participants identify as transgender?", hint_text: "0–100%", width: :quarter)
ae_number!(form, "What percentage of your participants have a gender identity not listed above?", hint_text: "0–100%", width: :half)
ae_field!(form, "For participants whose gender identities are not listed above, please specify how they identify", :free_form_input_paragraph, width: :half)

# ── Program impact on you ────────────────────────────────────────────────────
ae_header!(form, "Program impact on you")
impact_personal = ae_field!(form, "How would you rate the impact of our program in bringing about positive change in your personal life?", :single_select_radio, required: true, options: EFFECTIVENESS)
impact_professional = ae_field!(form, "How would you rate the impact of our program in bringing about positive change in your professional life?", :single_select_radio, required: true, options: EFFECTIVENESS)
ae_field!(form, "Please select all the ways our program has brought about positive change in your personal and professional life.", :multi_select_checkbox,
  subtitle: "Select all that apply.",
  options: [
    "Gained a deeper understanding of trauma and its impact",
    "Enhanced creativity and innovative thinking",
    "Increased self-confidence as a facilitator / leader",
    "Developed stronger interpersonal relationships with colleagues",
    "Enhanced ability to empathize with and support others",
    "Increased resilience and adaptability to challenges",
    "Developed a stronger sense of self-awareness and self-compassion",
    "Gained a deeper understanding of one's own trauma history and its impact",
    "Improved ability to identify and/or manage stress and burnout",
    "Enhanced ability to use art as a tool for self-expression and healing",
    "Developed a stronger sense of community and belonging",
    "Gained a deeper understanding of ethical considerations in trauma-informed practice",
    "Improved ability to advocate for and/or meet the needs of trauma survivors",
    "Other"
  ])
examples = ae_field!(form, "Can you share specific examples of how our program has positively impacted your life, both personally and/or professionally?", :free_form_input_paragraph,
  subtitle: "Please elaborate on any significant changes, skills gained, or challenges overcome.")
stress = ae_field!(form, "How would you rate the level of stress and burnout in your life?", :single_select_radio, required: true,
  options: [ "High", "Medium", "Low", "Little to none" ])

# ── Spread the word ──────────────────────────────────────────────────────────
ae_header!(form, "Spread the word")
recommend = ae_field!(form, "How likely are you to recommend the Windows program and our two-day training to someone you know?", :single_select_radio, required: true,
  options: [ "Highly likely", "Likely", "Neutral", "Unlikely", "Highly unlikely" ])
outreach = ae_field!(form, "Would you like to join our Training & Outreach Team to help share about our upcoming trainings?", :single_select_radio, required: true,
  subtitle: "Simply spreading the word about AWBW's trainings and resources can make an impact.",
  options: [ "Yes", "Not at this time" ])
ae_field!(form, "Do you know of any individuals or organizations that might be interested in joining our community of art facilitators?", :free_form_input_paragraph,
  subtitle: "If so, please provide their names, email addresses, and any relevant website information.")
one_word = ae_field!(form, "Please share one word that sums up your experience with art facilitation this year.", :free_form_input_one_line)
ae_field!(form, "Anything else you'd like to share with us?", :free_form_input_paragraph)

# Prune any fields a previous seeding created that are no longer defined above,
# so re-running converges the form to exactly this definition.
form.form_fields.where.not(id: @seeded_field_ids).destroy_all

# ── Sample submissions ───────────────────────────────────────────────────────
# The primary-age-group field stores an AgeRange category id (like a real dynamic
# submission), so answers reference the seeded categories rather than a label.
age_categories = CategoryType.find_by(name: "AgeRange")&.categories&.published&.order(:position)&.to_a || []
positions = [ "Facilitator", "Program Director", "Art Therapist", "Volunteer", "Clinician" ]
pronoun_options = [ "She/Her", "He/Him", "They/Them" ]
license_kinds = [ "LCSW", "LMFT", "MA Ed.", "", "" ]
stress_levels = [ "High", "Medium", "Low", "Little to none" ]
recommend_levels = [ "Highly likely", "Highly likely", "Likely", "Neutral" ]
example_notes = [
  "Facilitating at a domestic violence shelter, I've watched participants rediscover their voice through art.",
  "The trauma-informed lens reshaped how I show up for the teens in my school program.",
  "", # left blank to show a realistic partial response rate
  "I brought expressive arts into our outpatient program and my own self-care has grown alongside it.",
  "Working with elders, legacy and gratitude themes resonate most — and I feel more grounded myself."
]

respondent_count = 20

respondent_count.times do |i|
  person = Person.find_or_create_by!(email: "annual-eval-#{i + 1}@example.com") do |p|
    p.first_name = "Evaluation"
    p.last_name = "Facilitator #{i + 1}"
  end

  submission = FormSubmission.find_or_create_by!(form: form, person: person, role: "public")
  submission.update_columns(created_at: (respondent_count - i).days.ago, updated_at: (respondent_count - i).days.ago)

  answers = {
    first_name_field => person.first_name,
    last_name_field => person.last_name,
    pronouns_field => pronoun_options[i % pronoun_options.size],
    organization_field => "Sample Organization #{i + 1}",
    position_title => positions[i % positions.size],
    license_kind_field => license_kinds[i % license_kinds.size],
    primary_email => person.email,
    primary_email_type => WORK_PERSONAL[i % 2],
    outside_us => (i % 8).zero? ? "Yes" : "No",
    other_language => (i % 5).zero? ? "Yes" : "No",
    pct_one_on_one => [ 10, 20, 30, 40, 50, 60 ][i % 6].to_s,
    pct_groups => [ 90, 80, 70, 60, 50, 40 ][i % 6].to_s,
    reach_children => [ 40, 15, 0, 60, 25 ][i % 5].to_s,
    reach_teens => [ 30, 45, 10, 0, 55 ][i % 5].to_s,
    reach_adults => [ 60, 80, 120, 35, 20 ][i % 5].to_s,
    reach_elders => [ 10, 0, 25, 5, 40 ][i % 5].to_s,
    pct_families => [ 20, 35, 40, 25, 30 ][i % 5].to_s,
    primary_age => (age_categories.any? ? age_categories[i % age_categories.size].id.to_s : nil),
    impact_future => IMPACT_SCALE[i % 3],
    impact_resilience => IMPACT_SCALE[i % 3],
    without_awbw => YES_NO[i % 2],
    pct_alaskan => [ 0, 5, 0, 10, 0 ][i % 5].to_s,
    pct_asian => [ 5, 0, 15, 10, 0 ][i % 5].to_s,
    pct_black => [ 20, 30, 10, 40, 25 ][i % 5].to_s,
    pct_latinx => [ 30, 40, 20, 15, 45 ][i % 5].to_s,
    pct_white => [ 35, 25, 45, 20, 30 ][i % 5].to_s,
    pct_female => [ 70, 60, 80, 55, 65 ][i % 5].to_s,
    pct_male => [ 25, 35, 15, 40, 30 ][i % 5].to_s,
    pct_poverty => [ 60, 75, 40, 90, 50 ][i % 5].to_s,
    impact_personal => EFFECTIVENESS[i % 3],
    impact_professional => EFFECTIVENESS[i % 3],
    stress => stress_levels[i % stress_levels.size],
    recommend => recommend_levels[i % recommend_levels.size],
    outreach => (i % 5).zero? ? "Yes" : "Not at this time",
    one_word => [ "Transformative", "Healing", "Hopeful", "Connection", "Grateful" ][i % 5],
    examples => example_notes[i % example_notes.size]
  }

  answers.each do |field, value|
    next if value.blank?
    next if submission.form_answers.where(form_field: field).any?
    submission.form_answers.create!(form_field: field, submitted_answer: value, question_name_when_answered: field.name)
  end
end

puts "  → \"#{form.display_name}\": #{form.form_fields.count} fields, #{form.form_submissions.count} submissions (/forms/#{form.id}/results)"
