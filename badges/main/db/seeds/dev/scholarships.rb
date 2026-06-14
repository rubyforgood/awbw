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
# Most of these event-allocated scholarships are drawn from a parent grant, so the
# recipients page (events/recipients) shows the funding donor's name — a mix of
# organization and individual (Person) funders, since a grant's donor is
# polymorphic. A few are left grant-free so the no-donor case is covered too.
#
# A couple of scholarship + payment combos are seeded alongside the payments in
# db/seeds/dev/payments.rb (Amy, Jessica); this file fills out the flagship
# training with a full set of recipients. Looks up (rather than requires) the
# events and people, skips gracefully when absent, and skips any registration
# that already has a scholarship so it is safe to re-run.

puts "Seeding Scholarships for dev event registrations…"

facilitator_training = Event.find_by(title: "AWBW Facilitator Training")

# Every event that asks the scholarship questions (has a scholarship EventForm).
# Reused below to surface non-flagship applicants and print the per-event summary.
scholarship_events = Event.joins(:event_forms).where(event_forms: { role: "scholarship" }).distinct.to_a

# --- Grants (funding sources) ----------------------------------------------
# Create the grants up front so the event-allocated scholarships below can be
# drawn from them (recipients page → donor name). Grants cap the total
# scholarship dollars from a single source, so amounts are sized to comfortably
# cover both the event-allocated draws here and the standalone grant awards
# further down.
#   * a mix of donor types — three organization funders and two individual
#     (Person) funders, since donor is polymorphic;
#   * distinct donation totals, eligibility criteria, and tasks per grant.
puts "Seeding Grants…"

# Resolve a grant's donor by type: organizations by name, individuals by their
# first/last name (so a Person can fund a grant, mirroring the polymorphic donor).
resolve_donor = ->(donor_type, donor_name) do
  if donor_type == "Person"
    first, last = donor_name.split(" ", 2)
    Person.find_by(first_name: first, last_name: last)
  else
    Organization.find_by(name: donor_name)
  end
end

# [ name, donor_type, donor name, amount_cents, [ standalone award amounts… ], eligibility, tasks ]
grant_plans = [
  [ "Healing Arts Scholarship Fund", "Organization", "Joyful Heart Foundation", 2_000_000, [ 250_000, 150_000, 100_000 ],
    "Lead expressive-arts groups for trauma survivors\nServe a community-based partner organization",
    "Submit a portfolio of past workshops\nComplete the trauma-informed facilitation training\nFile a post-program impact report" ],
  [ "Community Resilience Grant", "Organization", "Angel Step Inn", 1_500_000, [ 250_000, 150_000 ],
    "Serve youth or families affected by community violence\nOperate in an underserved neighborhood",
    "Outline a six-week workshop plan\nPartner with a local school or shelter\nShare participant feedback after the series" ],
  [ "Trauma-Informed Practice Grant", "Organization", "Good Shepherd Shelter", 1_200_000, [ 300_000 ],
    "Be a licensed clinician or peer-support specialist\nIntegrate art into ongoing therapeutic work",
    "Describe your current caseload\nComplete the required continuing-education hours" ],
  [ "Survivor Empowerment Grant", "Person", "Maria Johnson", 800_000, [ 200_000, 100_000 ],
    "Work directly with domestic-violence survivors\nHold a current advocate or counselor role",
    "Provide two professional references\nAttend the grantee orientation call" ],
  [ "Creative Recovery Fund", "Person", "Lisa Williams", 1_000_000, [ 200_000, 150_000 ],
    "Facilitate art groups for adults in substance-use recovery\nHold at least a year of group facilitation experience",
    "Submit a one-page program proposal\nComplete a background check\nPresent outcomes at the year-end grantee showcase" ]
]

# Build the grants, re-syncing funder + descriptive fields for grants left over
# from an earlier run. Indexed by plan so the standalone-award amounts stay paired
# with their grant.
grants = grant_plans.filter_map do |(name, donor_type, donor_name, amount_cents, _awards, eligibility, tasks)|
  donor = resolve_donor.(donor_type, donor_name)
  next unless donor

  grant = Grant.find_or_create_by!(name: name) do |g|
    g.donor = donor
    g.amount_cents = amount_cents
    g.application_deadline = Date.current + 30
    g.funds_received_on = Date.current - 30
    g.eligibility_criteria = eligibility
    g.tasks = tasks
  end

  if grant.donor != donor || grant.amount_cents != amount_cents ||
     grant.eligibility_criteria != eligibility || grant.tasks != tasks
    grant.update!(donor: donor, amount_cents: amount_cents, eligibility_criteria: eligibility, tasks: tasks)
  end

  grant
end

# Round-robin across grants for donor variety, but only hand back one that can
# still absorb this award within its donation cap; returns nil when none has room
# (the scholarship is then created grant-free).
grant_cursor = 0
pick_grant_for = ->(amount_cents) do
  return nil if grants.empty?

  grants.length.times do
    grant = grants[grant_cursor % grants.length]
    grant_cursor += 1
    drawn = Scholarship.where(grant: grant).sum(:amount_cents)
    return grant if drawn + amount_cents <= grant.amount_cents
  end
  nil
end

# Mirrors ScholarshipsController: build the scholarship with a $0 allocation, then
# set amount + tasks_completed so sync_allocation_amount funds the allocation only
# when the recipient's tasks are complete (completed → allocated; pending → $0).
# When grant_funded, draws the award from a parent grant so the recipients page
# can name the funding donor.
award_scholarship = ->(registration, amount_cents:, tasks_completed:, grant_funded: false) do
  return unless registration
  return if registration.scholarships.exists?

  grant = grant_funded ? pick_grant_for.(amount_cents) : nil
  scholarship = Scholarship.new(recipient: registration.registrant, grant: grant)
  scholarship.build_allocation(allocatable: registration, amount: 0)
  scholarship.save!
  scholarship.update!(amount_cents: amount_cents, tasks_completed: tasks_completed)
end

# --- Scholarship application answers ---
# Give the recipients page (events/recipients) real content to show. Mirrors how
# scholarship applications actually arrive, in two shapes:
#   * combo — the registrant answered the scholarship questions inside their
#     registration, so the answers live on the registration submission;
#   * second form — the registrant submitted a separate scholarship form alongside
#     their registration, so the answers live on that scholarship submission.
# Every recipient has a registration submission either way (none have only a
# scholarship submission). Recipients are flagged scholarship_requested so they
# appear on that page. Reasonable answers to every scholarship question, inspired
# by actual recipient responses, are cycled across recipients for variety, along
# with a matching primary service area, age group, and a non-facilitator agency
# affiliation (title + organization) so the recipient header renders like the real
# export.
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

# Fully set up one scholarship recipient: flag the registration, ensure a
# registration submission carrying the recipient's identity + professional (header)
# answers and an agency affiliation, then attach the scholarship answers either to
# that registration submission (combo) or to a separate scholarship-form submission
# (second_form). Answer sets and affiliations are cycled for variety. Idempotent:
# every write checks for an existing answer first.
application_index = 0
setup_recipient = ->(registration, second_form:) do
  person = registration.registrant
  event = registration.event
  set = scholarship_answer_sets[application_index % scholarship_answer_sets.length]
  registration.update!(scholarship_requested: true) unless registration.scholarship_requested?

  reg_submission = ensure_registration_submission.(person, event)
  attach_header_answers.(reg_submission, set) if reg_submission
  ensure_recipient_affiliation.(person, event, set, recipient_orgs[application_index % recipient_orgs.length]) if recipient_orgs.any?

  if second_form && scholarship_form
    separate = FormSubmission.find_or_create_by!(person: person, form: scholarship_form, role: "scholarship")
    attach_scholarship_answers.(separate, set)
  elsif reg_submission
    attach_scholarship_answers.(reg_submission, set)
  end

  application_index += 1
end

# --- Flagship demo: AWBW Facilitator Training — exactly 6 recipients out of the
# 10-registrant cohort, split the way scholarship applications actually arrive:
#   * 4 answered the scholarship questions inside their registration (combo), and
#   * 2 submitted a separate scholarship form alongside their registration.
# The other 4 registrants stay plain (no scholarship requested). Amy already holds
# a flagship scholarship from the payments seed, so she counts as one of the six;
# the rest are filled from cohort registrants that still have room for an award. ---
if facilitator_training
  cost = facilitator_training.cost_cents
  flagship_regs = facilitator_training.event_registrations.active.order(:id).to_a
  already_awarded = flagship_regs.select { |reg| reg.scholarships.exists? }
  # Only registrations with no allocations yet have room for a full/partial award —
  # the allocation validation rejects allocating more than the remaining cost.
  fillable = flagship_regs.reject { |reg| reg.scholarships.exists? || reg.allocations.exists? }
  recipients = (already_awarded + fillable).first(6)

  # Fund the newly chosen recipients (Amy already has hers from payments); varied
  # shares and completion states give the dashboard both allocated and pending awards.
  # Most draw from a parent grant so the recipients page shows the funding donor;
  # one is left grant-free to cover the no-donor case.
  # [ share of the registration fee, tasks_completed, grant_funded ]
  award_plan = [ [ 1.0, true, true ], [ 0.5, true, true ], [ 0.75, false, true ], [ 0.5, true, true ], [ 0.25, false, false ] ]
  plan_index = 0
  recipients.each do |registration|
    next if registration.scholarships.exists?
    share, completed, grant_funded = award_plan[plan_index % award_plan.length]
    award_scholarship.(registration, amount_cents: (cost * share).round, tasks_completed: completed, grant_funded: grant_funded)
    plan_index += 1
  end

  # Hold the recipient count at exactly six: clear the flag on anyone left over.
  (flagship_regs - recipients).each do |registration|
    registration.update!(scholarship_requested: false) if registration.scholarship_requested?
  end

  # First four answered within their registration (combo); last two submitted a
  # separate scholarship form.
  recipients.each_with_index do |registration, i|
    setup_recipient.(registration, second_form: i >= 4)
  end
end

# --- Other scholarship-enabled events: surface their existing applicants
# (registrants who already hold a scholarship or requested one — e.g. Jessica on
# the trauma training), each answering within their registration submission. ---
(scholarship_events - [ facilitator_training ].compact).each do |event|
  event.event_registrations.active.order(:id).each do |registration|
    next unless registration.scholarships.exists? || registration.scholarship_requested?
    setup_recipient.(registration, second_form: false)
  end
end

scholarship_events.each do |event|
  dashboard = EventDashboard.new(event)
  puts "  #{event.title}: scholarships #{dashboard.scholarship_total_cents / 100.0} " \
       "(#{dashboard.scholarship_recipient_count} recipients)"
end

# --- Standalone grant-funded scholarships ----------------------------------
# Beyond the event-allocated awards above (which now draw from these grants too),
# seed a few standalone grant awards — recipient + grant, no event allocation —
# mirroring the grant CRUD flow, so the grant pages show draws and remaining
# balances. Idempotent: only adds standalone awards to a grant that has none yet,
# and skips any award that would exceed the grant's remaining funds.
puts "Seeding standalone grant-funded scholarships…"

# Reuse existing dev people as recipients, cycling so each award goes to a
# distinct person where the pool allows.
grant_recipient_pool = Person.order(:id).to_a
recipient_cursor = 0
next_recipient = -> do
  person = grant_recipient_pool[recipient_cursor % grant_recipient_pool.length]
  recipient_cursor += 1
  person
end

# A standalone grant scholarship has no allocation (event-allocated ones do).
grant_has_standalone = ->(grant) do
  Scholarship.where(grant: grant).left_outer_joins(:allocation).where(allocations: { id: nil }).exists?
end

grant_plans.each do |(name, _donor_type, _donor_name, _amount_cents, awards, _eligibility, _tasks)|
  grant = grants.find { |g| g.name == name }
  next unless grant && grant_recipient_pool.any?
  next if grant_has_standalone.(grant)

  awards.each_with_index do |award_cents, j|
    drawn = Scholarship.where(grant: grant).sum(:amount_cents)
    next if drawn + award_cents > grant.amount_cents

    Scholarship.create!(recipient: next_recipient.(), grant: grant,
                        amount_cents: award_cents, tasks_completed: j.even?)
  end

  puts "  #{grant.name}: #{grant.scholarships.count} scholarships, remaining #{grant.remaining_dollars}"
end

puts "  Scholarship seeds complete!"
