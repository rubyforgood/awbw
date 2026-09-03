# Form results showcase (dev-only).
#
# One standalone form that exercises EVERY FormField answer type, plus ~30
# submissions with deliberately varied answers, so the per-form results page
# (/forms/:id/results) has something rich to look at: pie + bar charts for the
# select/checkbox questions (including the dynamic sector/age-group fields that
# store ids), "Other / please specify" write-in lists, free-text answer lists,
# an average/total/range summary for the number questions, and a file-upload
# count. Group-header and informational fields are included so the input-less
# types are represented too (they're skipped in the rollup).
#
# Idempotent: the form is looked up by slug, fields by name, submissions by
# (form, person), and each answer is skipped when already present. Distributions
# are index-driven (no randomness) so reseeding is stable.

puts "Creating form-results showcase form…"

form = Form.standalone.find_by(slug: "field-type-showcase")
unless form
  form = Form.create!(name: "Field type showcase", slug: "field-type-showcase", published: true,
                      header: "A demo form covering every question type, for the results page.")
end

# Dynamic-field option sources (seeded in the base seeds). Nil-safe: if a fresh
# DB somehow lacks them, those fields just get no answers rather than blowing up.
age_categories = CategoryType.find_by(name: "AgeRange")&.categories&.published&.order(:position)&.to_a || []
sectors = Sector.published.order(:name).first(6)

def upsert_field!(form, name, answer_type, position, options: [], field_identifier: nil, required: false,
                  input_type: :text_alphanumeric)
  field = form.form_fields.find_by(name: name)
  field ||= form.form_fields.create!(name: name, answer_type: answer_type, position: position,
                                     status: :active, required: required, field_identifier: field_identifier,
                                     input_type: input_type)
  options.each_with_index do |option_name, index|
    answer_option = AnswerOption.find_or_create_by!(name: option_name) { |ao| ao.position = index + 1 }
    FormFieldAnswerOption.find_or_create_by!(form_field: field, answer_option: answer_option)
  end
  field
end

header = upsert_field!(form, "About you", :group_header, 1)
full_name = upsert_field!(form, "Your name", :free_form_input_one_line, 2)
about = upsert_field!(form, "Tell us a bit about your work", :free_form_input_paragraph, 3)
medium = upsert_field!(form, "Favorite art medium", :single_select_radio, 4,
                       options: [ "Painting", "Collage", "Clay", "Drawing", "Journaling" ])
heard = upsert_field!(form, "How did you hear about us?", :single_select_dropdown, 5,
                      options: [ "Website", "Social media", "Word of Mouth", "Foundation/Funder", "Other" ])
topics = upsert_field!(form, "Which topics interest you?", :multi_select_checkbox, 6,
                       options: [ "Self-care", "Grief", "Empathy", "Communication", "Safety and security" ])
region = upsert_field!(form, "Which region are you in?", :single_select_radio, 7,
                       options: [ "Pacific", "Mountain", "Midwest", "Southwest", "Southeast", "Northeast", "Mid-Atlantic", "International" ])
age_group = upsert_field!(form, "Primary age group you serve", :single_select_dropdown, 8, field_identifier: "primary_age_group")
sector_field = upsert_field!(form, "Additional sectors you serve", :multi_select_checkbox, 9, field_identifier: "additional_sectors")
# Geographic fields — charted as US-state / world choropleths (like the roster
# breakdowns) off their field_identifier, even though captured as free text.
state_field = upsert_field!(form, "Which state are you in?", :free_form_input_one_line, 10, field_identifier: "mailing_state")
country_field = upsert_field!(form, "Which country are you in?", :free_form_input_one_line, 11, field_identifier: "mailing_country")
info = upsert_field!(form, "Thanks for sharing — the rest is optional.", :no_user_input, 12)
upload = upsert_field!(form, "Upload a sample of your work", :file_upload, 13)
# Number questions are one-line inputs with a numeric input_type — that's what
# makes them roll up as average / total / range instead of a text answer list.
served = upsert_field!(form, "People served in a typical month", :free_form_input_one_line, 14,
                       input_type: :number_integer)
hours = upsert_field!(form, "Hours of programming you run each week", :free_form_input_one_line, 15,
                      input_type: :number_decimal)

states = [ "California", "Texas", "New York", "Florida", "Washington", "Illinois", "Massachusetts", "Oregon", "Georgia", "Ohio" ]
countries = [ "United States", "United States", "United States", "Canada", "United Kingdom", "Australia", "Mexico" ]

paragraphs = [
  "I run weekly art groups at a domestic violence shelter and love AWBW's approach.",
  "Working with teens in a school setting — the trauma-informed lens has been a game changer.",
  "I'm a clinician bringing expressive arts into an outpatient program.",
  "", # left blank on purpose to show a partial answer rate
  "Facilitating with elders in a residential program; gratitude and legacy themes resonate most.",
  "New to facilitation and excited to bring this to my community center."
]
heard_answers = [
  "Website",
  "Social media",
  "Word of Mouth: a colleague at a conference",
  "Other: Facebook group",
  "Website",
  "Foundation/Funder: The Example Foundation"
]
mediums = [ "Painting", "Collage", "Clay", "Drawing", "Journaling" ]
regions = [ "Pacific", "Mountain", "Midwest", "Southwest", "Southeast", "Northeast", "Mid-Atlantic", "International" ]
all_topics = [ "Self-care", "Grief", "Empathy", "Communication", "Safety and security" ]
# Wide spread so the average, total, and range each read differently. The blank
# and the "varies" leave a partial answer rate, and show that a non-numeric stray
# is dropped from the figures rather than skewing them.
served_counts = [ "12", "45", "8", "120", "30", "", "64", "6", "250", "18", "varies" ]
weekly_hours = [ "2.5", "6", "1.5", "12", "3.75", "8", "", "4", "20.5", "0.5" ]

respondent_count = 30

respondent_count.times do |i|
  person = Person.find_or_create_by!(email: "showcase#{i + 1}@example.com") do |p|
    p.first_name = "Showcase"
    p.last_name = "Respondent #{i + 1}"
  end

  submission = FormSubmission.find_or_create_by!(form: form, person: person, role: "public")
  # Spread submissions across ~two months so the results header shows a range.
  submission.update_columns(created_at: (respondent_count - i).days.ago, updated_at: (respondent_count - i).days.ago)

  # Each submission answers a varied subset; index-driven so reseeding is stable.
  answers = {
    full_name => person.name,
    about => paragraphs[i % paragraphs.size],
    medium => mediums[i % mediums.size],
    heard => heard_answers[i % heard_answers.size],
    region => regions[i % regions.size],
    state_field => states[i % states.size],
    country_field => countries[i % countries.size],
    # A rotating 1–3 topic subset, so the multi-select bar chart varies.
    topics => all_topics.each_with_index.select { |_, j| (i + j) % 3 == 0 }.map(&:first).join(", "),
    # Every third respondent skips the file upload, for a realistic count.
    upload => (i % 3 == 2 ? "" : "sample_#{i + 1}.jpg"),
    served => served_counts[i % served_counts.size],
    hours => weekly_hours[i % weekly_hours.size]
  }
  answers[age_group] = age_categories[i % age_categories.size].id.to_s if age_categories.any?
  # 1–3 sectors as their ids, joined like a real multi-select submission.
  answers[sector_field] = sectors.each_with_index.select { |_, j| (i + j) % 2 == 0 }.map { |s, _| s.id }.first(3).join(", ") if sectors.any?

  answers.each do |field, value|
    next if value.blank?
    next if submission.form_answers.where(form_field: field).any?
    submission.form_answers.create!(form_field: field, submitted_answer: value, question_name_when_answered: field.name)
  end
end

puts "  → #{form.form_submissions.count} submissions on \"#{form.display_name}\" (/forms/#{form.id}/results)"
