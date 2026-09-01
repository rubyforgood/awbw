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

form = Form.standalone.find_by(slug: "annual-evaluation-2025")
form ||= Form.create!(name: "Annual Evaluation 2025", slug: "annual-evaluation-2025", published: true, header: INTRO)

@position = 0

def ae_field!(form, name, answer_type, options: [], field_identifier: nil, input_type: nil, required: false, subtitle: nil, hint_text: nil)
  @position += 1
  field = form.form_fields.find_by(name: name)
  field ||= form.form_fields.create!(name: name, answer_type: answer_type, position: @position, status: :active,
                                     required: required, field_identifier: field_identifier, input_type: input_type,
                                     subtitle: subtitle, hint_text: hint_text)
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
ae_header!(form, "About you")
full_name = ae_field!(form, "First and Last Name", :free_form_input_one_line, required: true)
ae_field!(form, "Pronouns", :multi_select_checkbox,
  subtitle: "This helps us understand the correct way to address you. Select all that apply.",
  options: [ "She/Her", "He/Him", "They/Them", "I prefer not to say", "Other" ])
agency = ae_field!(form, "Agency Name (where you facilitate art workshops)", :free_form_input_one_line,
  required: true, field_identifier: "organization_name",
  subtitle: "If you're not associated with an agency, please provide the name of your art program.")
ae_field!(form, "Agency website URL", :free_form_input_one_line, required: true, field_identifier: "organization_website")
position_title = ae_field!(form, "Your Position / Title", :free_form_input_one_line, required: true)
primary_email = ae_field!(form, "Primary Email Address", :free_form_input_one_line, required: true, field_identifier: "primary_email")
primary_email_type = ae_field!(form, "Primary Email Address Type", :single_select_radio, required: true, options: WORK_PERSONAL)
ae_field!(form, "I'd like to add a secondary email address", :single_select_radio, required: true,
  subtitle: "So we can keep in touch should you move on from your organization.", options: YES_NO)
ae_field!(form, "Secondary Email Address", :free_form_input_one_line, field_identifier: "secondary_email")
ae_field!(form, "Secondary Email Address Type", :single_select_radio, options: WORK_PERSONAL)
ae_header!(form, "Academic credentials (if applicable)", subtitle: "e.g., LCSW, MFT, MA Ed., etc.")
ae_field!(form, "Credential 1", :free_form_input_one_line)
ae_field!(form, "Credential 2", :free_form_input_one_line)
ae_field!(form, "Credential 3", :free_form_input_one_line)

# ── Your work ────────────────────────────────────────────────────────────────
ae_header!(form, "Your work")
outside_us = ae_field!(form, "Do you offer art workshops outside of the United States?", :single_select_radio, required: true, options: YES_NO)
ae_field!(form, "If you offer workshops outside the US, please share which countries", :free_form_input_paragraph)
other_language = ae_field!(form, "Do you facilitate art workshops in languages other than English?", :single_select_radio, required: true, options: YES_NO)
ae_field!(form, "If you facilitate in other languages, please share which languages", :free_form_input_paragraph)
pct_one_on_one = ae_number!(form, "What percentage of your art workshops are one-on-one?", hint_text: "0–100%")
pct_groups = ae_number!(form, "What percentage of your art workshops are with groups?", hint_text: "0–100%")
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
reach_children = ae_number!(form, "Children (ages 0-12)", required: true)
reach_teens = ae_number!(form, "Teens (ages 13-17)", required: true)
reach_adults = ae_number!(form, "Adults (age 18-64)", required: true)
reach_elders = ae_number!(form, "Elders (age 65+)", required: true)
pct_families = ae_number!(form, "What percentage of participants consists of families of two or more individuals?", required: true,
  subtitle: "Family relationships can include parents, children, siblings, grandparents, aunts, uncles, and more.")
primary_age = ae_field!(form, "What is the primary age group you serve through art workshops?", :single_select_radio, required: true,
  subtitle: "Select one.",
  options: [ "Elders (65+)", "Adults (18-64)", "Teens (13-17)", "Children (0-12)", "Children & Teens (0-17)", "Families" ])

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
pct_alaskan = ae_number!(form, "What percentage of your participants are Alaskan Native?", hint_text: "0–100%")
ae_number!(form, "What percentage of your participants are American Indian or Native American?", hint_text: "0–100%")
pct_asian = ae_number!(form, "What percentage of your participants are Asian?", hint_text: "0–100%")
pct_black = ae_number!(form, "What percentage of your participants are Black or African American?", hint_text: "0–100%")
pct_latinx = ae_number!(form, "What percentage of your participants are Latinx?", hint_text: "0–100%")
ae_number!(form, "What percentage of your participants are Middle Eastern?", hint_text: "0–100%")
ae_number!(form, "What percentage of your participants are multi-racial?", hint_text: "0–100%")
ae_number!(form, "What percentage of your participants are Native Hawaiian or other Pacific Islander?", hint_text: "0–100%")
pct_white = ae_number!(form, "What percentage of your participants are White?", hint_text: "0–100%")
ae_number!(form, "What percentage of your participants are of an ethnicity not listed above?", hint_text: "0–100%")
ae_field!(form, "For participants whose ethnic identities are not listed above, please specify their ethnicities", :free_form_input_paragraph)

# ── Participant gender identity ──────────────────────────────────────────────
ae_header!(form, "Participant gender identity",
  subtitle: "What percentage of your participants identify as the following? Please use your best estimations.")
pct_female = ae_number!(form, "What percentage of your participants identify as female?", hint_text: "0–100%")
pct_male = ae_number!(form, "What percentage of your participants identify as male?", hint_text: "0–100%")
ae_number!(form, "What percentage of your participants identify as non-binary?", hint_text: "0–100%")
ae_number!(form, "What percentage of your participants identify as transgender?", hint_text: "0–100%")
ae_number!(form, "What percentage of your participants have a gender identity not listed above?", hint_text: "0–100%")
ae_field!(form, "For participants whose gender identities are not listed above, please specify how they identify", :free_form_input_paragraph)
pct_poverty = ae_number!(form, "What percentage of your participants are at or below the Federal Poverty Line?",
  hint_text: "See the 2024 Federal Poverty Level Guidelines. 0–100%")

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

# ── Sample submissions ───────────────────────────────────────────────────────
positions = [ "Facilitator", "Program Director", "Art Therapist", "Volunteer", "Clinician" ]
age_groups = [ "Adults (18-64)", "Teens (13-17)", "Children (0-12)", "Families", "Elders (65+)", "Children & Teens (0-17)" ]
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
    full_name => person.name,
    agency => "Sample Agency #{i + 1}",
    position_title => positions[i % positions.size],
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
    primary_age => age_groups[i % age_groups.size],
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
