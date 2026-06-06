# Events management seeds (dev-only) - run on their own via `rake db:seed:events_management`,
# or as part of `rake db:seed:dev`. Creates the standalone registration/scholarship forms, the
# dev events that share them, event registrations for named scenarios, and form submissions.
# Named people are looked up when present (e.g. after `rake db:seed:people_profiles`).

puts "Creating standalone registration forms…"
unless Form.standalone.exists?(name: "Registration")
  FormBuilderService.new(
    name: "Registration",
    sections: %i[person_identifier],
    role: "registration"
  ).call
end

unless Form.standalone.find_by(role: "scholarship")
  FormBuilderService.new(
    name: "Scholarship Application",
    sections: %i[scholarship],
    role: "scholarship"
  ).call
end

puts "Creating Events with shared forms…"
admin_user = User.find_by(email: "umberto.user@example.com")
registration_form = Form.standalone.find_by!(role: "registration")
scholarship_form = Form.standalone.find_by!(role: "scholarship")

# Each entry: [title, form_type, cost_cents, scholarship?, visibility, span_days]
# form_type: :long, :short, or :none. span_days (optional) makes a multi-day event.
dev_events = [
  [ "AWBW Facilitator Training", :long, 15_000, true,
    { published: true, featured: true, publicly_visible: true } ],
  [ "Facilitator Training: Trauma-Informed Art Practices", :long, 12_000, true,
    { published: true, featured: true }, 3 ],
  [ "A Year of Healing and Rebuilding Together Wellness Day", :short, 0, false,
    { published: true, publicly_visible: true, publicly_featured: true, featured: true } ],
  [ "Youth Creativity Day", :short, 0, false,
    { published: true, publicly_visible: true, publicly_featured: true } ],
  [ "Mindful Art for Survivors Workshop", :short, 5_000, true,
    { published: true, publicly_visible: true, publicly_featured: true } ],
  [ "Community Open Studio Night", :none, 0, false,
    { published: true, featured: true } ],
  [ "Annual Celebration of Voices", :none, 0, false,
    { published: true, publicly_visible: true } ],
  [ "Art as Healing: Virtual Group Session", :short, 0, false,
    { published: true, featured: true } ],
  [ "Leaders in Creativity: Facilitator Roundtable", :short, 0, false,
    { published: true, publicly_visible: true } ],
  [ "Family Creative Expression Day", :short, 0, false,
    { published: true, publicly_visible: true, publicly_featured: true } ],
  [ "Creative Safety & Support Workshop", :short, 2_500, true,
    { published: true, featured: true } ],
  [ "Healing Through Art: Spring Community Gathering", :short, 0, false,
    { published: true, publicly_visible: true } ]
]

dev_events.each_with_index do |(title, form_type, cost_cents, scholarship, visibility, span_days), i|
  # Soonest events sort last; index order is start_date DESC, so reversing the
  # offset puts the first two entries (the data-rich trainings) at the top of the list.
  start_date = Time.current + ((dev_events.length - i) * 5).days
  end_date = start_date + (span_days ? (span_days - 1).days : 0) + rand(2..4).hours
  registration_close = start_date - rand(2..7).days
  registerable = form_type != :none

  desc_content = Faker::Lorem.paragraph(sentence_count: 6)
  event = Event.find_or_create_by!(title: title) do |e|
    e.description = desc_content
    e.rhino_description = desc_content
    e.start_date = start_date
    e.end_date = end_date
    e.registration_close_date = registration_close
    e.cost_cents = cost_cents
    e.public_registration_enabled = false
    e.created_by = admin_user
    visibility.each { |k, v| e.send(:"#{k}=", v) }
  end

  # Keep the demo schedule current and deterministic on re-seed — find_or_create_by!
  # only sets dates on create, so without this an existing DB keeps stale dates and
  # neither the index ordering nor the multi-day span would update.
  event.update!(start_date: start_date, end_date: end_date, registration_close_date: registration_close)

  if registerable
    EventForm.find_or_create_by!(event: event, role: "registration") do |ef|
      ef.form = registration_form
    end
    event.update!(public_registration_enabled: true) unless event.public_registration_enabled?
  end

  if scholarship
    EventForm.find_or_create_by!(event: event, role: "scholarship") do |ef|
      ef.form = scholarship_form
    end
  end
end

puts "Creating Event Registrations…"

# Key people for named scenarios
amy_person = User.find_by(email: "amy.user@example.com")&.person
maria_j = Person.find_by(first_name: "Maria", last_name: "Johnson")
anna_g = Person.find_by(first_name: "Anna", last_name: "Garcia")
sarah_s = Person.find_by(first_name: "Sarah", last_name: "Smith")
lisa_w = Person.find_by(first_name: "Lisa", last_name: "Williams")
jessica_b = Person.find_by(first_name: "Jessica", last_name: "Brown")
kim_d = Person.find_by(first_name: "Kim", last_name: "Davis")
rosa_dlc = Person.find_by(first_name: "Rosa", last_name: "De La Cruz")
mario_j = Person.find_by(first_name: "Mario", last_name: "Johnson") # no user
angel_g = Person.find_by(first_name: "Angel", last_name: "Garcia") # no user
linda_w = Person.find_by(first_name: "Linda", last_name: "Williams") # no user

# Events by name for clarity
facilitator_training = Event.find_by(title: "AWBW Facilitator Training")
trauma_training = Event.find_by(title: "Facilitator Training: Trauma-Informed Art Practices")
wellness_day = Event.find_by(title: "A Year of Healing and Rebuilding Together Wellness Day")
youth_day = Event.find_by(title: "Youth Creativity Day")
mindful_art = Event.find_by(title: "Mindful Art for Survivors Workshop")
virtual_session = Event.find_by(title: "Art as Healing: Virtual Group Session")
roundtable = Event.find_by(title: "Leaders in Creativity: Facilitator Roundtable")
family_day = Event.find_by(title: "Family Creative Expression Day")
# "Community Open Studio Night" and "Annual Celebration of Voices" have no registration forms — left with zero registrations

registrations_data = []

# --- Facilitator Training: multiple registrations from different people, extended form ---
# Amy: registered, with form submission, scholarship recipient
# Maria Johnson: registered, with form submission (has user)
# Anna Garcia: attended, with form submission (has user)
# Mario Johnson: registered, no form submission (no user)
# Kim Davis: cancelled (has user)
if facilitator_training
  [
    { person: amy_person, status: "registered", scholarship_requested: true },
    { person: maria_j, status: "registered" },
    { person: anna_g, status: "attended" },
    { person: mario_j, status: "registered" },
    { person: kim_d, status: "cancelled" }
  ].each do |data|
    next unless data[:person]
    registrations_data << data.merge(event: facilitator_training)
  end
end

# --- Trauma Training: extended form, scholarship ---
# Sarah Smith: registered with form (has user)
# Jessica Brown: registered with form, scholarship (has user)
# Angel Garcia: registered, no form (no user)
# Linda Williams: no_show (no user)
if trauma_training
  [
    { person: sarah_s, status: "registered" },
    { person: jessica_b, status: "registered", scholarship_requested: true },
    { person: angel_g, status: "registered" },
    { person: linda_w, status: "no_show" }
  ].each do |data|
    next unless data[:person]
    registrations_data << data.merge(event: trauma_training)
  end
end

# --- Amy registered to multiple events (person registered across events) ---
if amy_person
  [ wellness_day, mindful_art, virtual_session ].compact.each do |evt|
    registrations_data << { person: amy_person, event: evt, status: "registered" }
  end
end

# --- Maria Johnson also registered to multiple events ---
if maria_j
  [ wellness_day, youth_day ].compact.each do |evt|
    registrations_data << { person: maria_j, event: evt, status: "registered" }
  end
end

# --- Rosa De La Cruz registered to a couple events (has user) ---
if rosa_dlc
  [ wellness_day, family_day ].compact.each do |evt|
    registrations_data << { person: rosa_dlc, event: evt, status: "registered" }
  end
end

# --- Lisa Williams: incomplete_attendance on one event ---
if lisa_w && roundtable
  registrations_data << { person: lisa_w, event: roundtable, status: "incomplete_attendance" }
end

# --- People with multiple active affiliations — ensures org snapshots get exercised ---
mariana_j = Person.find_by(first_name: "Mariana", last_name: "Johnson")
samuel_s = Person.find_by(first_name: "Samuel", last_name: "Smith")
lisa_wn = Person.find_by(first_name: "Lisa", last_name: "Williamson")
kim_dv = Person.find_by(first_name: "Kim", last_name: "Davidson")
sarah_d = Person.find_by(first_name: "Sarah", last_name: "Davis")

{ mariana_j => youth_day, samuel_s => mindful_art, lisa_wn => virtual_session,
  kim_dv => family_day, sarah_d => roundtable }.each do |person, evt|
  next unless person && evt
  registrations_data << { person: person, event: evt, status: "registered" }
end

# --- Wellness Day gets extra registrations (popular free event, short form) ---
if wellness_day
  [ sarah_s, jessica_b, lisa_w, kim_d ].compact.each do |person|
    registrations_data << { person: person, event: wellness_day, status: "registered" }
  end
end

# Create all registrations
registrations_data.each do |data|
  next unless data[:event] && data[:person]
  next if EventRegistration.exists?(event: data[:event], registrant: data[:person])

  EventRegistration.create!(
    event: data[:event],
    registrant: data[:person],
    status: data[:status] || "registered",
    scholarship_requested: data[:scholarship_requested] || false
  )
end

# Backfill slugs for any registrations created before the generate_slug callback existed
EventRegistration.where(slug: nil).find_each do |reg|
  reg.update!(slug: SecureRandom.urlsafe_base64(16))
end

puts "Creating Registration Form Submissions…"
# Create form_submission records linking registrants to their event's registration form.
# This simulates people who filled out the registration form.
form_submissions = []

# Facilitator Training (extended form) — some registrants filled it out, one didn't
if facilitator_training
  reg_form = facilitator_training.registration_form
  if reg_form
    # People with users who filled out the form
    [ amy_person, maria_j, anna_g ].compact.each do |person|
      form_submissions << { person: person, form: reg_form }
    end
    # Mario Johnson (no user) did NOT fill out the form — registration without form submission
  end
end

# Trauma Training (extended form)
if trauma_training
  reg_form = trauma_training.registration_form
  if reg_form
    # Sarah Smith (has user) and Jessica Brown (has user) filled out forms
    [ sarah_s, jessica_b ].compact.each do |person|
      form_submissions << { person: person, form: reg_form }
    end
    # Angel Garcia (no user) filled out the form — person without user + form
    form_submissions << { person: angel_g, form: reg_form } if angel_g
    # Linda Williams (no user) did NOT fill out the form
  end
end

# Wellness Day (short form) — most filled it out
if wellness_day
  reg_form = wellness_day.registration_form
  if reg_form
    # People with users
    [ amy_person, maria_j, sarah_s, jessica_b, kim_d ].compact.each do |person|
      form_submissions << { person: person, form: reg_form }
    end
    # Rosa (has user) filled it out too
    form_submissions << { person: rosa_dlc, form: reg_form } if rosa_dlc
    # Lisa Williams (has user) registered but didn't fill out the form — person with user + no form
  end
end

# Mindful Art (short form, has scholarship) — Amy filled out the form
if mindful_art
  reg_form = mindful_art.registration_form
  form_submissions << { person: amy_person, form: reg_form } if reg_form && amy_person
end

# Youth Day (short form) — Maria filled it out
if youth_day
  reg_form = youth_day.registration_form
  form_submissions << { person: maria_j, form: reg_form } if reg_form && maria_j
end

# Virtual Session (short form) — Amy (has user) registered but no form submission — person with user + no form
# Family Day (short form) — Rosa filled it out
if family_day
  reg_form = family_day.registration_form
  form_submissions << { person: rosa_dlc, form: reg_form } if reg_form && rosa_dlc
end

# Create all form submissions with sample field responses
form_submissions.each do |data|
  next unless data[:person] && data[:form]
  next if FormSubmission.exists?(person: data[:person], form: data[:form])

  pf = FormSubmission.create!(person: data[:person], form: data[:form])

  # Fill in required text fields with sample data
  data[:form].form_fields.where(answer_type: [ :free_form_input_one_line, :free_form_input_paragraph ]).each do |field|
    sample_text = case field.field_identifier
    when "first_name" then data[:person].first_name
    when "last_name" then data[:person].last_name
    when "primary_email", "enter_email", "confirm_email" then data[:person].preferred_email || "sample@example.com"
    when "phone" then "(555) #{rand(100..999)}-#{rand(1000..9999)}"
    when "street_address", "agency_street_address" then Faker::Address.street_address
    when "city", "agency_city" then Faker::Address.city
    when "state_province", "agency_state_province" then Faker::Address.state_abbr
    when "zip_postal_code", "agency_zip_postal_code" then Faker::Address.zip_code
    when "agency_organization_name" then Faker::Company.name
    when "position_title" then "Facilitator"
    when "agency_website" then "https://example.org"
    when "racial_ethnic_identity" then "Prefer not to say"
    when "secondary_email" then data[:person].email_2
    when "preferred_nickname" then data[:person].first_name
    when "pronouns" then [ "she/her", "he/him", "they/them" ].sample
    else
      if field.answer_type == "free_form_input_paragraph"
        Faker::Lorem.paragraph(sentence_count: 3)
      else
        Faker::Lorem.word.capitalize
      end
    end

    FormAnswer.create!(
      form_submission: pf,
      form_field: field,
      submitted_answer: sample_text.to_s,
      question_name_when_answered: field.name
    )
  end
end
