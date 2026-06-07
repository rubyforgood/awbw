# Scholarship seeds (dev-only) — run on their own via `rake db:seed:scholarships`,
# or as part of `rake db:seed:dev`.
#
# Seeds scholarships on the paid dev events created in
# db/seeds/dev/events_management.rb, covering both states the dashboard needs to
# show:
#   * completed (tasks_completed: true) — Scholarship#sync_allocation_amount funds
#     the allocation, so the dollars are applied to the registration and count
#     toward the grand total ("Completed & allocated").
#   * pending (tasks_completed: false) — the allocation stays $0, so the award is
#     visible as "potentially awarded" but the registrant still owes the cost.
#
# A couple of scholarship + payment combos are seeded alongside the payments in
# db/seeds/dev/payments.rb (Amy, Jessica); this file fills out the flagship
# training with a full set of recipients. Looks up (rather than requires) the
# events and people, skips gracefully when absent, and skips any registration
# that already has a scholarship so it is safe to re-run.

puts "Seeding Scholarships for dev event registrations…"

facilitator_training = Event.find_by(title: "AWBW Facilitator Training")
trauma_training = Event.find_by(title: "Facilitator Training: Trauma-Informed Art Practices")
mindful_art = Event.find_by(title: "Mindful Art for Survivors Workshop")

angel_g = Person.find_by(first_name: "Angel", last_name: "Garcia")
samuel_s = Person.find_by(first_name: "Samuel", last_name: "Smith")

# Mirrors ScholarshipsController: build the scholarship with a $0 allocation, then
# set amount + tasks_completed so sync_allocation_amount funds the allocation only
# when the recipient's tasks are complete (completed → allocated; pending → $0).
award_scholarship = ->(registration, amount_cents:, tasks_completed:) do
  return unless registration
  return if registration.scholarships.exists?

  scholarship = Scholarship.new(recipient: registration.registrant)
  scholarship.build_allocation(allocatable: registration, amount: 0)
  scholarship.save!
  scholarship.update!(amount_cents: amount_cents, tasks_completed: tasks_completed)
end

award_for_person = ->(event, person, **opts) do
  return unless event && person
  award_scholarship.(EventRegistration.find_by(event: event, registrant: person), **opts)
end

# --- Flagship demo: AWBW Facilitator Training — 10 scholarships across its
# cohort, each a full or partial share of the registration fee, with roughly half
# completed (dollars allocated, counting toward the grand total) and half pending
# (awarded but unallocated). ---
if facilitator_training
  cost = facilitator_training.cost_cents
  # [ share of the registration fee, tasks_completed ]
  plan = [
    [ 1.0,  true ], [ 0.75, true ], [ 0.5,  true ], [ 1.0,  true ], [ 0.25, true ],
    [ 1.0,  false ], [ 0.5,  false ], [ 0.6,  false ], [ 0.4,  false ], [ 0.33, false ]
  ]
  active_regs = facilitator_training.event_registrations.active.to_a
  needed = [ 10 - active_regs.count { |reg| reg.scholarships.exists? }, 0 ].max
  # Only fund registrations with no allocations yet, so a full or partial award
  # fits within the event cost. A registrant who already paid has less room left,
  # and the allocation validation rejects allocating more than the remaining cost.
  candidates = active_regs.reject { |reg| reg.allocations.exists? }
  plan.first(needed).each_with_index do |(share, completed), i|
    registration = candidates[i]
    next unless registration
    award_scholarship.(registration, amount_cents: (cost * share).round, tasks_completed: completed)
  end
end

# --- A couple more on other paid events for cross-event variety ---
award_for_person.(mindful_art, samuel_s, amount_cents: 5_000, tasks_completed: true)
award_for_person.(trauma_training, angel_g, amount_cents: 6_000, tasks_completed: false)

# --- Scholarship application answers ---
# Give the recipients page (events/recipients) real content to show. Mirrors how
# the data actually arrives:
#   * every recipient has a registration submission — none have only a
#     scholarship submission;
#   * most answered the scholarship questions while registering (one form, two
#     parts), so those answers live on the registration submission;
#   * a few have a separate scholarship submission alongside it.
# Recipients are flagged scholarship_requested so they appear on that page.
# Reasonable answers to every scholarship question, inspired by actual recipient
# responses, are cycled across recipients for variety, along with a matching
# primary service area, age group, and a non-facilitator agency affiliation
# (title + organization) so the recipient header renders like the real export.
puts "Seeding Scholarship application answers…"

# Keyed by the scholarship form's field identifiers (see
# FormBuilderService#build_scholarship_fields).
scholarship_answer_sets = [
  {
    "impact_description" =>
      "The people I serve are survivors of sexual assault who are often rebuilding a sense of safety in their own bodies. " \
      "What I gain from this training will let me offer art as a gentle, non-verbal way to process trauma when words feel impossible. " \
      "I'll be able to hold steadier, more trauma-informed space and recognize when a participant needs grounding instead of pushing forward. " \
      "Over time that means survivors leave each session feeling more seen and more in control of their own healing.",
    "implementation_plan" =>
      "I plan to run a weekly drop-in art workshop at our advocacy center where survivors can come without an appointment. " \
      "We would open with a short grounding exercise and then a simple, low-pressure prompt like 'a safe place' that anyone can attempt. " \
      "I envision it becoming a consistent, predictable space that helps participants reconnect with choice and self-expression at their own pace.",
    "additional_comments" =>
      "Thank you for considering my application. A scholarship is the only way my small agency can send me to this training right now, " \
      "and the ripple effect on the survivors we serve would be immediate.",
    "service_area" => "Sexual Assault",
    "age_group" => "18+",
    "title" => "Prevention, Education, and Outreach Specialist"
  },
  {
    "impact_description" =>
      "I'm a behavioral health clinician working with clients managing anxiety, depression, and complex trauma. " \
      "This training will give me concrete, creative tools to reach clients who shut down in traditional talk therapy. " \
      "Bringing art into sessions helps regulate the nervous system and gives clients a way to externalize what they're carrying. " \
      "The result is more engaged clients and breakthroughs that simply don't happen with conversation alone.",
    "implementation_plan" =>
      "One way I'd use art workshops is a six-week group for clients in early recovery, each week building on a theme like trust or resilience. " \
      "Participants would create one piece per session and reflect together in a closing circle. " \
      "I envision the shared making and witnessing reducing isolation and helping members feel they aren't alone in their experience.",
    "additional_comments" =>
      "I've wanted formal facilitation training for years but our continuing-education budget was cut. This scholarship would change that.",
    "service_area" => "Mental Health",
    "age_group" => "Mixed-age groups",
    "title" => "Behavioral Health Clinician"
  },
  {
    "impact_description" =>
      "I work with youth and teens who have witnessed community violence and often don't have the language for what they feel. " \
      "What I learn here will help me meet them where they are and let art carry the parts that are too hard to say out loud. " \
      "Trauma-informed facilitation means I can keep the space safe when strong emotions surface instead of accidentally re-traumatizing anyone. " \
      "Ultimately the young people I serve gain a healthy outlet and a trusted adult who understands their experience.",
    "implementation_plan" =>
      "I'd like to offer an after-school art workshop series at our youth center, paced so each session ends with everyone feeling settled. " \
      "We'd use accessible materials and prompts about identity, hope, and belonging. " \
      "I envision it giving teens a consistent place to process their week and build confidence through finishing something that's theirs.",
    "additional_comments" =>
      "Our program serves families at no cost, so outside funding for my training is what makes this possible. Thank you.",
    "service_area" => "Child Abuse",
    "age_group" => "6-12",
    "title" => "Youth Program Coordinator"
  },
  {
    "impact_description" =>
      "As a peer support specialist with lived experience, I serve adults navigating recovery and housing instability. " \
      "This training will deepen my ability to use art as a bridge to connection when trust is hard to come by. " \
      "I'll be better equipped to notice triggers, offer grounding, and let people set the pace of their own work. " \
      "The people I serve benefit from a facilitator who both understands their journey and has the skills to hold the room safely.",
    "implementation_plan" =>
      "I plan to weave a short art practice into our existing weekly support group so members can express what they're not ready to speak. " \
      "Each person would keep a simple visual journal across the weeks to see their own progress. " \
      "I envision it strengthening the group's sense of community and giving members a tangible reminder of how far they've come.",
    "additional_comments" =>
      "I'm so grateful for this opportunity. Investing in me is investing in everyone I'll go on to support.",
    "service_area" => "Domestic Violence",
    "age_group" => "18+",
    "title" => "Peer Support Specialist"
  }
]

# The scholarship-section field records live on the standalone scholarship form
# (FormBuilderService scholarship section). Answers reference these fields no
# matter which submission they hang off, so the recipients page — which gathers
# by field identifier — finds them either way.
scholarship_form = Form.standalone.find_by(role: "scholarship")
scholarship_fields = scholarship_form ? scholarship_form.form_fields.where.not(answer_type: :group_header).to_a : []

# Make sure the registration form asks the professional questions, so each
# recipient's primary service area and age group are captured as registration
# answers — the recipients page reads those first, then falls back to the
# person's profile (sectors / age-range tags).
registration_form = Form.standalone.find_by(role: "registration")
if registration_form && registration_form.form_fields.where(field_identifier: "primary_service_area").none?
  FormBuilderService.update_sections!(registration_form, (registration_form.sections || []).map(&:to_sym) | [ :professional_info ])
end
service_area_field = registration_form&.form_fields&.find_by(field_identifier: "primary_service_area")
age_group_field = registration_form&.form_fields&.find_by(field_identifier: "primary_age_group")

# Existing dev organizations (excluding AWBW itself) to affiliate recipients
# with, cycled alongside the answer sets.
recipient_orgs = Organization.where.not(name: "A Window Between Worlds").order(:name).to_a

# Capture the recipient's professional answers on their registration submission,
# storing the sector / age-range ids the professional fields expect.
attach_header_answers = ->(submission, set) do
  sector = Sector.published.find_by(name: set["service_area"])
  if service_area_field && sector && submission.form_answers.where(form_field: service_area_field).none?
    submission.form_answers.create!(form_field: service_area_field, submitted_answer: sector.id.to_s, question_name_when_answered: service_area_field.name)
  end

  age_category = Category.age_ranges.published.find_by(name: set["age_group"])
  if age_group_field && age_category && submission.form_answers.where(form_field: age_group_field).none?
    submission.form_answers.create!(form_field: age_group_field, submitted_answer: age_category.id.to_s, question_name_when_answered: age_group_field.name)
  end
end

# Give the recipient a non-facilitator affiliation active at the event so the
# recipients page can show their organization and title. Skips anyone who
# already has a qualifying affiliation.
ensure_recipient_affiliation = ->(person, event, set, org) do
  return unless org
  return if person.affiliations.any? { |a| !a.facilitator? && !a.inactive? }

  start_date = (event.start_date || Time.current).to_date - 1.year
  person.affiliations.create!(organization: org, title: set["title"], start_date: start_date)
end

# Ensure the recipient has a registration submission (no recipient should have
# only a scholarship submission), creating a minimal one with their identity
# fields when missing — most cohort registrants were generated without a form.
ensure_registration_submission = ->(person, event) do
  reg_form = event.registration_form
  return unless reg_form

  submission = FormSubmission.find_or_create_by!(person: person, form: reg_form)
  reg_form.form_fields.where.not(answer_type: :group_header).each do |field|
    value = case field.field_identifier
    when "first_name" then person.first_name
    when "last_name" then person.last_name
    when "primary_email", "confirm_email" then person.preferred_email || "#{person.first_name}.#{person.last_name}@seed.example.com".downcase
    end
    next if value.blank?
    next if submission.form_answers.exists?(form_field: field)

    submission.form_answers.create!(form_field: field, submitted_answer: value, question_name_when_answered: field.name)
  end
  submission
end

# Attach the scholarship answers to a submission (the registration submission for
# most recipients, a separate scholarship submission for a few).
attach_scholarship_answers = ->(submission, answers) do
  scholarship_fields.each do |field|
    answer = answers[field.field_identifier]
    answer ||= "Yes" if field.field_identifier == "scholarship_eligibility"
    next if answer.blank?
    next if submission.form_answers.exists?(form_field: field)

    submission.form_answers.create!(form_field: field, submitted_answer: answer, question_name_when_answered: field.name)
  end
end

application_index = 0
[ facilitator_training, trauma_training, mindful_art ].compact.each do |event|
  event.event_registrations.active.find_each do |registration|
    next unless registration.scholarships.exists?

    person = registration.registrant
    registration.update!(scholarship_requested: true) unless registration.scholarship_requested?
    set = scholarship_answer_sets[application_index % scholarship_answer_sets.length]

    reg_submission = ensure_registration_submission.(person, event)

    # Service area + age group are registration answers (the recipients page
    # reads them there first); the affiliation supplies the org + title.
    attach_header_answers.(reg_submission, set) if reg_submission
    ensure_recipient_affiliation.(person, event, set, recipient_orgs[application_index % recipient_orgs.length]) if recipient_orgs.any?

    # Most recipients answered the scholarship questions as part of registering
    # (one form, two parts); every fourth keeps a separate scholarship submission.
    if (application_index % 4 == 3) && scholarship_form
      separate = FormSubmission.find_or_create_by!(person: person, form: scholarship_form, role: "scholarship")
      attach_scholarship_answers.(separate, set)
    elsif reg_submission
      attach_scholarship_answers.(reg_submission, set)
    end

    application_index += 1
  end
end

[ facilitator_training, trauma_training, mindful_art ].compact.each do |event|
  dashboard = EventDashboard.new(event)
  puts "  #{event.title}: scholarships #{dashboard.scholarship_total_cents / 100.0} " \
       "(#{dashboard.scholarship_recipient_count} recipients), " \
       "allocated #{dashboard.allocated_scholarship_cents / 100.0}, " \
       "outstanding #{dashboard.outstanding_scholarship_cents / 100.0}"
end

puts "  Scholarship seeds complete!"
