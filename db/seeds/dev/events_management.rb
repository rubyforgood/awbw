# Events management seeds (dev-only) - run on their own via `rake db:seed:events_management`,
# or as part of `rake db:seed:dev`. Creates the standalone registration/scholarship forms, the
# dev events that share them, event registrations for named scenarios, and form submissions.
# Named people are looked up when present (e.g. after `rake db:seed:people_profiles`).

puts "Creating standalone registration forms…"
unless Form.standalone.exists?(name: "Training Registration Form")
  FormBuilderService.new(
    name: "Training Registration Form",
    sections: %i[person_identifier professional_info payment],
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

unless Form.standalone.find_by(role: "bulk_payment")
  FormBuilderService.new(
    name: "Bulk Payment",
    sections: %i[bulk_payment],
    role: "bulk_payment"
  ).call
end

puts "Creating Events with shared forms…"
admin_user = User.find_by(email: "umberto.user@example.com")
registration_form = Form.standalone.find_by!(role: "registration")
scholarship_form = Form.standalone.find_by!(role: "scholarship")
bulk_payment_form = Form.standalone.find_by!(role: "bulk_payment")

# Seed an example header (admin-authored HTML intro shown under the form title on
# the public registration page) onto the base registration form, mirroring the
# real AWBW Facilitator Training copy. Training dates, time, fee, and platform are
# intentionally omitted — the public page already renders those from the event
# (the date/time block, the "Cost:" badge, and the videoconference/platform badge),
# and the form itself already notes that fields marked * are required. The form is
# shared across events, so event-specific dates use tokens filled at render time
# (see form_header_html): {{event_month_year}} from the event's start date and
# {{registration_close}} from its registration close date, rather than hard-coded
# values. Only set when blank so admin edits survive a re-seed.
if registration_form.header.blank?
  registration_form.update!(header: <<~HTML.strip)
    <p style="font-size:17px;color:#166534;"><strong>We're so glad you're here.</strong></p>
    <p>This training certifies you to lead trauma-informed creative art workshops, guiding adults, youth, and children through the AWBW model and the quiet, transformative work of making art together. Attending this training is required to facilitate Windows workshops.</p>
    <p>Along the way, you'll experience the process hands-on as a maker yourself. Once you're certified, you'll join our Community of Practice with full access to the AWBW curriculum, ongoing training, and support services. Your training fee includes <a href="https://awbw.org/programs/what-awbw-offers-windows-facilitators/" target="_blank" rel="noopener" style="font-weight:600;">these ongoing benefits</a>, and <a href="https://awbw.org/programs/ce-hours-for-facilitator-trainings/" target="_blank" rel="noopener" style="font-weight:600;">Continuing Education (CE) hours</a> are available.</p>
    <p><strong style="color:#b45309;">Registration closes {{registration_close}}.</strong> Payment is due within three weeks of registering, and we'll send everything you need as the dates approach.</p>
    <p style="font-size:13px;color:#6b7280;"><em>There are no refunds for Windows Facilitator Trainings, though you're welcome to transfer your spot to a later training or a co-worker with AWBW's approval.</em></p>
    <p style="background-color:#faf5ff;border:1px solid #e9d5ff;border-radius:12px;padding:16px 18px;color:#6b21a8;"><strong style="font-size:16px;">Ready when you are.</strong> Fill out the form below to claim your spot.<br><span style="color:#7e22ce;">You'll get a confirmation email shortly. If not, email us at <a href="mailto:trainings@awbw.org" style="color:#7e22ce;">trainings@awbw.org</a>.</span></p>
  HTML
end

# Seed a scholarship-specific header, shown under the "Scholarship application"
# heading when this form is appended to an event registration (see
# events/public_registrations/new). Scoped strictly to scholarship concerns —
# eligibility and what's asked of recipients — and deliberately does NOT repeat
# anything already in the registration header above (dates/time/platform, fee, CE
# hours, refund/transfer policy, confirmation email, registration close), since
# both headers render on the same page. Styled to match the registration header so
# the section reads as inviting rather than a wall of requirements. Only set when
# blank so admin edits survive a re-seed.
if scholarship_form.header.blank?
  scholarship_form.update!(header: <<~HTML.strip)
    <p style="font-size:17px;color:#166534;"><strong>Cost shouldn't stand between you and this work.</strong></p>
    <p>If the training fee is a barrier, apply for a scholarship right here — there's no separate form, just the questions below.</p>
    <p><strong>Scholarships are currently available for:</strong></p>
    <ul>
      <li>Those located in <strong>Los Angeles County</strong>, California (limit 1 per agency)</li>
      <li>Those located in <strong>Orange County</strong>, California (limit 1 per agency)</li>
      <li>Those located in the <strong>Coachella Valley</strong>, California</li>
      <li>Those within a 30-mile radius of <strong>Victorville</strong>, CA</li>
      <li>Individuals working in <strong>movement building, community organizing</strong>, and/or <strong>systems change work</strong></li>
      <li>Individuals serving <strong>fire-impacted communities</strong></li>
    </ul>
    <p>If we're able to offer you a scholarship, we'll ask you to give a little back to the community in return:</p>
    <ul>
      <li>Respond to 3 short questions after the training</li>
      <li>Share quarterly highlight stories with images of participant artwork</li>
    </ul>
    <p style="font-size:13px;color:#6b7280;"><em>More details come with your notification. Scholarship recipients still attend both full days of the training.</em></p>
    <p style="background-color:#faf5ff;border:1px solid #e9d5ff;border-radius:12px;padding:16px 18px;color:#6b21a8;"><strong style="font-size:16px;">No need to choose between cost and care.</strong> Answer the questions below to apply — we review every request personally.</p>
  HTML
end

# Ensure the professional section (Primary Age Group(s) Served, Primary Service
# Area, etc.) exists even on a registration form seeded before it was added — the
# event Background charts aggregate answers to those questions.
if registration_form.form_fields.where(field_identifier: "primary_age_group").none?
  FormBuilderService.update_sections!(registration_form, (registration_form.sections || []).map(&:to_sym) | [ :professional_info ])
end

# The CE-interest "magic question": a single Yes/No whose answer drives the
# resulting registration's ce_credit_requested flag (see
# EventRegistrationServices::PublicRegistration). Seeded straight onto the form
# with its own section so the form builder's add/remove-section logic leaves it
# alone, and carrying the well-known field_identifier the service keys off.
ce_identifier = EventRegistrationServices::PublicRegistration::CE_CREDIT_INTEREST_IDENTIFIER
if registration_form.form_fields.where(field_identifier: ce_identifier).none?
  next_position = (registration_form.form_fields.maximum(:position) || 0) + 1
  registration_form.form_fields.create!(
    name: "Continuing education",
    answer_type: :group_header,
    status: :active,
    position: next_position,
    required: false,
    section: "continuing_education",
    visibility: :always_ask
  )
  ce_field = registration_form.form_fields.create!(
    name: "Might you be seeking continuing education (CE) hours for attending this training?",
    answer_type: :single_select_radio,
    status: :active,
    position: next_position + 1,
    required: false,
    field_identifier: ce_identifier,
    section: "continuing_education",
    visibility: :always_ask,
    width: :full,
    hint_text: "CE hours are available for select trainings. Let us know and our team will follow up with details."
  )
  %w[Yes No].each_with_index do |opt, idx|
    ao = AnswerOption.find_or_create_by!(name: opt) { |a| a.position = idx }
    ce_field.form_field_answer_options.create!(answer_option: ao)
  end
end

# Each entry: [title, form_type, cost_cents, scholarship?, visibility, span_days]
# form_type: :long, :short, or :none. span_days (optional) makes a multi-day event.
dev_events = [
  [ "AWBW Facilitator Training", :long, 150_000, true,
    { published: true, featured: true, publicly_visible: true }, 2 ],
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

  # Keep the demo schedule and pricing current and deterministic on re-seed —
  # find_or_create_by! only sets these on create, so without this an existing DB
  # keeps stale dates/cost and neither the index ordering, the multi-day span, nor
  # the registration fee would update.
  event.update!(start_date: start_date, end_date: end_date, registration_close_date: registration_close, cost_cents: cost_cents)

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

  if cost_cents.to_i > 0
    EventForm.find_or_create_by!(event: event, role: "bulk_payment") do |ef|
      ef.form = bulk_payment_form
    end
  end
end

# The flagship training runs on Zoom — drive the platform from event settings so
# it shows as a badge in the public registration header (rather than living in the
# shared form header). It also turns on the structured "at a glance" details panel
# and carries the free-form qualifiers (hint_dates / hint_times / hint_registration_cost)
# so the seeded data demonstrates those grey parentheticals on its registration
# page. force-set on re-seed, mirroring the date/cost refresh above.
Event.find_by(title: "AWBW Facilitator Training")&.update!(
  videoconference_url: "https://awbw-org.zoom.us/j/0000000000",
  videoconference_label: "Zoom",
  autoshow_registration_details: true,
  hint_dates: "must attend both days",
  hint_times: "both days",
  hint_registration_cost: "due within 3 weeks of registration"
)

# Seed the "Before you attend" details — the materials/art-supply info that used to
# live in a long confirmation email and that registrants routinely missed. Shown on
# its own ticket-linked page (and via the prominent amber call-out on the ticket).
# A custom label demonstrates that the heading is admin-editable. Only set when
# blank so admin edits survive a re-seed.
flagship = Event.find_by(title: "AWBW Facilitator Training")
if flagship && flagship.rhino_event_details.blank?
  flagship.update!(event_details_label: "Art supplies & what to bring")
  flagship.rhino_event_details = <<~HTML.strip
    <p>We will be facilitating five hands-on art workshops, all of which can be done with paper, writing utensils (crayons, colored pencils, markers, etc.) and scissors.</p>
    <ul>
      <li>You'll receive printable workshop worksheets once your training fees are paid — printing them is optional.</li>
      <li>You're welcome to use any art supplies you like: oil/chalk pastels, paints, watercolors, collage materials, etc.</li>
      <li>You may want a journal or lined paper for writing.</li>
    </ul>
    <p>The lists below, grouped by workshop, are <strong>optional</strong> supplies you may want on hand. We'll demonstrate how to use them during the training.</p>
    <h3>Workshop 1</h3>
    <ul>
      <li>Clear glass stones</li>
      <li>Pendant settings (cabochon settings and swivel hooks to hold the glass stones)</li>
      <li>Hole punch to create paper circles — we recommend a 1.25" circle punch</li>
      <li>Paper for circles — white and/or colored cardstock, or printmaking paper painted with acrylics</li>
      <li>Glue to adhere paper circles to the glass stones — we recommend Aleene's Clear Gel Tacky Glue</li>
      <li>Clear packing tape</li>
    </ul>
    <h3>Workshop 2</h3>
    <ul>
      <li>Rough &amp; Ready Shrinky Dink paper</li>
      <li>Permanent markers</li>
      <li>Colored pencils (we recommend Prismacolor)</li>
      <li>A hole punch (single or three-hole is fine)</li>
      <li>Thin ribbon or wire (1/8 in. or thinner)</li>
      <li>An oven to cook the shrink paper (a toaster oven — not a toaster — works well)</li>
    </ul>
    <h3>Workshop 3</h3>
    <ul>
      <li>A glue stick (used in workshops 3 &amp; 5)</li>
      <li>Scotch tape</li>
      <li>Two copies of the dice handout (sent after fees are paid), printed on cardstock</li>
    </ul>
    <h3>Workshop 4</h3>
    <ul>
      <li>Oil-based pastels (we recommend Cray-Pas)</li>
      <li>Card/heavy stock or watercolor paper</li>
      <li>Watercolors (we recommend Prang)</li>
      <li>Cups for water</li>
      <li>Paintbrush</li>
      <li>Painter's tape</li>
    </ul>
    <h3>Workshop 5</h3>
    <ul>
      <li>Card/heavy stock paper</li>
      <li>Collage materials</li>
    </ul>
  HTML
  flagship.save!
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

puts "Creating Event Staff…"
# Staff the flagship training (event 1) so its "Meet the staff" page has content.
# Amy carries an event-specific bio that OVERRIDES her profile bio here, while
# Maria has no event bio so the page falls back to her profile bio — exercising
# both sides of the per-event bio feature. Profile bios are set so the fallback
# (and the edit form's "showing their profile bio" preview) have something to show.
# Updates run unconditionally so re-seeding keeps the demo bios current.
amy_person&.update!(
  bio: "Amy User is a Windows facilitator with a decade of experience bringing trauma-informed art practices to survivors across Los Angeles. She believes the quietest moments at the art table are often the most transformative.",
  profile_show_bio: true
)
maria_j&.update!(
  bio: "Maria Johnson coordinates community workshops and has supported AWBW programs since 2019, with a focus on youth and family groups.",
  profile_show_bio: true
)

if facilitator_training
  if amy_person
    amy_staff = EventStaff.find_or_create_by!(event: facilitator_training, person: amy_person)
    amy_staff.update!(
      title: "Lead facilitator",
      expected_to_attend: true,
      bio: "For the AWBW Facilitator Training, Amy leads the two-day intensive — walking new facilitators through the full Windows model and sharing what a decade at the art table has taught her about holding space."
    )
  end

  if maria_j
    maria_staff = EventStaff.find_or_create_by!(event: facilitator_training, person: maria_j)
    maria_staff.update!(title: "Facilitator", expected_to_attend: false, bio: nil)
  end
end

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

# Give the flagship training its demo cohort: top up to 10 active registrants with
# generated people (the named scenario registrants above are kept; this only fills
# the remainder). The scholarships seed makes 6 of these 10 scholarship recipients.
# Emails are deterministic so re-seeding is idempotent.
if facilitator_training
  (10 - facilitator_training.event_registrations.active.count).times do |i|
    person = Person.find_or_create_by!(email: "facilitator.cohort.#{i + 1}@seed.example.com") do |p|
      p.first_name = Faker::Name.first_name
      p.last_name = Faker::Name.last_name
    end
    EventRegistration.find_or_create_by!(event: facilitator_training, registrant: person) do |reg|
      reg.status = "registered"
    end
  end
end

# Backfill slugs for any registrations created before the generate_slug callback existed
EventRegistration.where(slug: nil).find_each do |reg|
  reg.update!(slug: SecureRandom.urlsafe_base64(16))
end

# Make sure every registrant on the data-rich demo events belongs to an
# organization, so the background page's Organizations count (and its
# new/ongoing/reinstated breakdown) reflects the whole cohort. Only registrants
# with no active affiliation get one — to an existing org, cycled for variety.
puts "Backfilling registrant affiliations for the demo events…"
backfill_orgs = Organization.where.not(name: "A Window Between Worlds").order(:name).to_a
if backfill_orgs.any?
  [ "AWBW Facilitator Training", "Facilitator Training: Trauma-Informed Art Practices",
    "Mindful Art for Survivors Workshop" ].each do |title|
    event = Event.find_by(title: title)
    next unless event
    event.event_registrations.active.includes(:registrant).each_with_index do |registration, i|
      person = registration.registrant
      next if person.affiliations.active.any?
      person.affiliations.create!(organization: backfill_orgs[i % backfill_orgs.length],
                                  title: "Facilitator", start_date: (event.start_date || Time.current).to_date - 2.years)
    end
  end
end

puts "Tagging registrants with life experiences and workshop settings…"
# The background page charts registrants' StoryPopulation (life experiences) and
# WorkshopEnvironment (settings) tags — the same tags public registration writes
# from the "Client life experiences" and "Workshop environments" checkboxes (see
# PublicRegistration#assign_tags). The seed form submissions above only fill text
# fields, so without this the data-rich trainings' background charts are empty.
# Tag each active registrant with a deterministic spread so re-seeding is idempotent.
life_experience_categories = Category.joins(:category_type)
  .where(category_types: { name: "StoryPopulation" })
  .order(:name).to_a
setting_categories = Category.joins(:category_type)
  .where(category_types: { name: "WorkshopEnvironment" })
  .order(:name).to_a

# Pick offsets i and i+offset from a category list, wrapping around; returns [] for
# an empty list so the seed survives running before the base category seeds.
pick_categories = ->(categories, i, offset) do
  return [] if categories.empty?
  [ categories[i % categories.size], categories[(i + offset) % categories.size] ]
end

[ facilitator_training, trauma_training ].compact.each do |evt|
  evt.event_registrations.active.includes(:registrant).each_with_index do |registration, i|
    person = registration.registrant
    next unless person

    # Each registrant gets two life experiences and two settings, offset by their
    # position so the charts show a realistic spread across categories.
    tags = (pick_categories.call(life_experience_categories, i, 2) +
            pick_categories.call(setting_categories, i, 3)).compact.uniq

    tags.each do |category|
      CategorizableItem.find_or_create_by!(category: category, categorizable: person)
    end
  end
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
      form_submissions << { person: person, form: reg_form, event: facilitator_training }
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
      form_submissions << { person: person, form: reg_form, event: trauma_training }
    end
    # Angel Garcia (no user) filled out the form — person without user + form
    form_submissions << { person: angel_g, form: reg_form, event: trauma_training } if angel_g
    # Linda Williams (no user) did NOT fill out the form
  end
end

# Wellness Day (short form) — most filled it out
if wellness_day
  reg_form = wellness_day.registration_form
  if reg_form
    # People with users
    [ amy_person, maria_j, sarah_s, jessica_b, kim_d ].compact.each do |person|
      form_submissions << { person: person, form: reg_form, event: wellness_day }
    end
    # Rosa (has user) filled it out too
    form_submissions << { person: rosa_dlc, form: reg_form, event: wellness_day } if rosa_dlc
    # Lisa Williams (has user) registered but didn't fill out the form — person with user + no form
  end
end

# Mindful Art (short form, has scholarship) — Amy filled out the form
if mindful_art
  reg_form = mindful_art.registration_form
  form_submissions << { person: amy_person, form: reg_form, event: mindful_art } if reg_form && amy_person
end

# Youth Day (short form) — Maria filled it out
if youth_day
  reg_form = youth_day.registration_form
  form_submissions << { person: maria_j, form: reg_form, event: youth_day } if reg_form && maria_j
end

# Virtual Session (short form) — Amy (has user) registered but no form submission — person with user + no form
# Family Day (short form) — Rosa filled it out
if family_day
  reg_form = family_day.registration_form
  form_submissions << { person: rosa_dlc, form: reg_form, event: family_day } if reg_form && rosa_dlc
end

# Create all form submissions with sample field responses
form_submissions.each do |data|
  next unless data[:person] && data[:form]
  next if FormSubmission.exists?(person: data[:person], form: data[:form])

  pf = FormSubmission.create!(person: data[:person], form: data[:form], event: data[:event])

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

puts "Giving Amy free-text \"Other\" answers on her Facilitator Training submission…"
# Demo data for the "Other" chips on the person profile + edit pages: a registrant
# who picked the "Other" option (folded into "Other: <text>") on a sector-backed
# field (Primary service area) and a category-backed field (Workshop Settings).
# These free-text values can't be Sector/Category records, so they only surface
# via Person#other_service_area_responses / #other_workshop_setting_responses.
# Seeded before the professional-answer enrichment below so the primary_service_area
# value survives its "skip if already answered" guard. Idempotent.
if facilitator_training && amy_person
  amy_submission = FormSubmission.find_by(person: amy_person, form: facilitator_training.registration_form)
  if amy_submission
    {
      "primary_service_area" => "Other: Equine-assisted therapy",
      "workshop_environments" => "Other: Mobile art van"
    }.each do |identifier, value|
      field = amy_submission.form.form_fields.find_by(field_identifier: identifier)
      next unless field
      answer = amy_submission.form_answers.find_or_initialize_by(form_field: field)
      answer.update!(submitted_answer: value, question_name_when_answered: field.name)
    end
  end
end

puts "Recording professional answers (age group / service area) on registration submissions…"
# The Background page charts the registrants' "Primary Age Group(s) Served" and
# "Primary Service Area(s)" registration answers. Public registration stores
# these checkbox answers as ", "-joined category / sector ids (see
# PublicRegistration#save_form_answers + assign_tags); seed them the same way so
# the charts have data. Age group is read from the form answers; service area is
# read from SectorableItem tags, so write both. Idempotent: skips a field already
# answered on a submission, and only enriches people who have a submission (so the
# "registered but didn't fill the form" scenarios stay answer-free).
age_range_categories = Category.age_ranges.published.order(:position, :name).to_a
service_area_sectors = Sector.published.order(:name).to_a

record_professional_answers = ->(submission, i) do
  person = submission.person
  form = submission.form

  age_field = form.form_fields.find_by(field_identifier: "primary_age_group")
  ages = pick_categories.call(age_range_categories, i, 2)
  if age_field && ages.present? && submission.form_answers.where(form_field: age_field).none?
    submission.form_answers.create!(form_field: age_field,
                                    submitted_answer: ages.map(&:id).join(", "),
                                    question_name_when_answered: age_field.name)
  end

  service_field = form.form_fields.find_by(field_identifier: "primary_service_area")
  sectors = service_area_sectors.empty? ? [] : [ service_area_sectors[i % service_area_sectors.size], service_area_sectors[(i + 4) % service_area_sectors.size] ].uniq
  if service_field && sectors.present? && submission.form_answers.where(form_field: service_field).none?
    submission.form_answers.create!(form_field: service_field,
                                    submitted_answer: sectors.map(&:id).join(", "),
                                    question_name_when_answered: service_field.name)
  end
  # Service area chart reads SectorableItem tags, mirroring assign_tags.
  sectors.each { |sector| SectorableItem.find_or_create_by!(sector: sector, sectorable: person) }
end

# Give the flagship cohort registration submissions so its Background charts have
# volume (named scenarios above are unchanged; the cohort are generic fill-ins).
if facilitator_training && (reg_form = facilitator_training.registration_form)
  facilitator_training.event_registrations.active.includes(:registrant).each do |registration|
    person = registration.registrant
    next unless person&.email.to_s.start_with?("facilitator.cohort.")
    FormSubmission.find_or_create_by!(person: person, form: reg_form) do |fs|
      fs.event = facilitator_training
    end
  end
end

# Enrich every registration submission on the registerable dev events.
[ facilitator_training, trauma_training, wellness_day, youth_day, mindful_art, virtual_session, roundtable, family_day ].compact.each do |evt|
  reg_form = evt.registration_form
  next unless reg_form

  evt.event_registrations.active.includes(:registrant).each_with_index do |registration, i|
    person = registration.registrant
    next unless person
    submission = FormSubmission.find_by(person: person, form: reg_form)
    next unless submission

    record_professional_answers.call(submission, i)
  end
end

puts "Ensuring registrants have address data (state + country) for the Background maps…"
# The Background page's States (US choropleth) and Countries (world choropleth)
# read Address records on each registrant. The registration form captures
# city/state/zip as free-text answers but never creates an Address; the people
# seed gives everyone a US address but leaves country blank — so the Countries map
# renders empty. For each event registrant: create an address if they have none
# (preferring their registration answers), and backfill country on the one they do
# have. A deterministic slice is made international so the world map has variety.
# Idempotent: re-running lands on the same per-registrant values.
us_states = %w[CA NY TX FL WA IL MA OR CO GA AZ MI MN NC PA]
# city, state/region, country — every 7th registrant gets one so the world map fills.
international = [ [ "Toronto", "ON", "Canada" ], [ "London", "England", "United Kingdom" ],
                 [ "Sydney", "NSW", "Australia" ], [ "Berlin", "Berlin", "Germany" ] ]

# Pull a registration answer by field identifier (blank/missing → nil).
answer_text = ->(submission, identifier) do
  next nil unless submission
  field = submission.form.form_fields.find_by(field_identifier: identifier)
  field && submission.form_answers.find_by(form_field: field)&.submitted_answer.presence
end

seen_registrants = {}
[ facilitator_training, trauma_training, wellness_day, youth_day, mindful_art, virtual_session, roundtable, family_day ].compact.each do |evt|
  reg_form = evt.registration_form

  evt.event_registrations.active.includes(registrant: :addresses).order(:registrant_id).each_with_index do |registration, i|
    person = registration.registrant
    next unless person
    next if seen_registrants[person.id]
    seen_registrants[person.id] = true

    submission = reg_form && FormSubmission.find_by(person: person, form: reg_form)
    overseas = international[(i / 7) % international.size] if (i % 7) == 6
    address = person.addresses.reject(&:inactive?).first

    if address
      # Backfill country so the Countries map fills; for the international slice,
      # move the location overseas so the world map shows non-US countries.
      if overseas
        address.update!(city: overseas[0], state: overseas[1], country: overseas[2])
      elsif address.country.blank?
        address.update!(country: "United States")
      end
    else
      city, state, country = overseas || [
        answer_text.call(submission, "city").presence || Faker::Address.city,
        answer_text.call(submission, "state_province").presence || us_states[i % us_states.size],
        "United States"
      ]
      Address.create!(
        addressable: person,
        street_address: answer_text.call(submission, "street_address").presence || Faker::Address.street_address,
        city: city,
        state: state,
        zip_code: answer_text.call(submission, "zip_postal_code").presence || Faker::Address.zip_code,
        country: country,
        locality: country == "United States" ? "Unknown" : "Outside USA",
        primary: true,
        inactive: false
      )
    end
  end
end

puts "Ensuring the flagship training has at least 3 international registrants…"
# The Background page's Countries world map and the roster's Location column only
# show non-US data when some registrants live abroad. The address pass above only
# sends an occasional registrant overseas, which can leave the flagship demo short.
# Guarantee a minimum for this event: count its active registrants already abroad
# and, if short, move the needed number of domestic ones overseas (deterministic).
# Idempotent — re-running finds the quota already met.
if facilitator_training
  minimum_international = 3
  abroad = ->(person) do
    address = person.addresses.reject(&:inactive?).first
    address && address.country.present? && address.country != "United States"
  end

  active_registrants = facilitator_training.event_registrations.active
    .includes(registrant: :addresses).order(:registrant_id).filter_map(&:registrant)
  shortfall = minimum_international - active_registrants.count { |person| abroad.call(person) }

  if shortfall.positive?
    active_registrants.reject { |person| abroad.call(person) }.first(shortfall).each_with_index do |person, idx|
      city, region, country = international[idx % international.size]
      address = person.addresses.reject(&:inactive?).first
      if address
        address.update!(city: city, state: region, country: country)
      else
        Address.create!(addressable: person, street_address: Faker::Address.street_address,
                        city: city, state: region, zip_code: Faker::Address.zip_code,
                        country: country, locality: "Outside USA", primary: true, inactive: false)
      end
    end
  end
end

puts "Adding shout-out bios to scholarship recipients' organizations…"
# The recipients page "Shout out scholarship programs" section pairs each
# scholarship recipient with their affiliated organization and that org's bio
# (description). Seed orgs ship without a description, so the section renders
# empty. Back-fill a realistic, hard-coded bio onto each scholarship recipient's
# program — only when blank, so any real data is preserved. update_columns skips
# validations/callbacks, which is fine for seed back-fill.
shoutout_bios = [
  "Provides trauma-informed art workshops and wraparound support to survivors of domestic violence and their children.",
  "Offers emergency shelter, counseling, and economic-empowerment programs that help families rebuild after abuse.",
  "Runs community-based healing circles and advocacy services for survivors across historically underserved neighborhoods.",
  "Delivers culturally responsive crisis intervention, legal advocacy, and long-term recovery programming.",
  "Supports survivors through safe housing, peer support, and creative-expression programming for all ages.",
  "Champions prevention education and survivor-led programming to break cycles of violence in the community."
]

recipient_orgs = [ facilitator_training, trauma_training ].compact
  .flat_map { |evt| EventDashboard.new(evt).scholarship_applicants }
  .uniq
  .filter_map { |person| person.affiliations.reject(&:inactive?).filter_map(&:organization).first }
  .uniq(&:id)

recipient_orgs.each_with_index do |org, i|
  next if org.description.present?
  org.update_columns(description: shoutout_bios[i % shoutout_bios.size])
end

puts "Recording school districts on registrant addresses…"
# The Background page breaks registrants out by school district (Address#district).
# The address pass above leaves district blank, so assign a deterministic spread
# to a subset of the data-rich trainings' US registrants. Idempotent: skips an
# address that already has a district, and only US addresses get one (K-12
# districts are domestic).
school_district_names = [ "Los Angeles Unified", "Garden Grove Unified", "Compton Unified",
                          "Riverside Unified", "Long Beach Unified" ]
[ facilitator_training, trauma_training ].compact.each do |evt|
  evt.event_registrations.active.includes(registrant: :addresses).order(:registrant_id).each_with_index do |registration, i|
    next unless i.even? # roughly half the registrants are tied to a district
    person = registration.registrant
    address = person&.addresses&.reject(&:inactive?)&.first
    next unless address && address.district.blank?
    next unless address.country.blank? || address.country == "United States"

    address.update!(district: school_district_names[(i / 2) % school_district_names.size])
  end
end

puts "Creating organization-link demo registrants on the flagship training…"
# Exercises every state of the registrants Organization column and the Link
# Organization editor: linked org(s), the amber "Pending" chip (the registrant
# typed an agency name that is not linked to an org), and the grey "None" chip
# (nothing submitted). Deterministic, clearly-named people so each state is easy
# to spot in the browser at the flagship event's registrants page. Runs last so
# the earlier affiliation backfill / form-fill passes leave these registrants
# exactly as configured here.
if facilitator_training && registration_form
  # "Pending" only exists when the form has the Agency / Organization Name field,
  # which lives in the person_contact_info section the dev form otherwise omits.
  unless registration_form.form_fields.exists?(field_identifier: "agency_name")
    FormBuilderService.update_sections!(
      registration_form,
      (registration_form.sections || []).map(&:to_sym) | [ :person_contact_info ]
    )
  end
  agency_field = registration_form.form_fields.find_by(field_identifier: "agency_name")

  # Real, existing orgs to link against / match on (skip the AWBW house org).
  demo_orgs = Organization.where.not(name: "A Window Between Worlds").order(:name).to_a
  matched_org = demo_orgs.first

  link_org = ->(registration, organization) do
    Affiliation.find_or_create_by!(person: registration.registrant, organization: organization) do |aff|
      aff.title = "Facilitator"
      aff.start_date = Date.current
    end
    registration.event_registration_organizations.find_or_create_by!(organization: organization)
  end

  submit_agency_name = ->(registration, value) do
    submission = FormSubmission.find_or_create_by!(person: registration.registrant, form: registration_form)
    if agency_field
      answer = submission.form_answers.find_or_initialize_by(form_field: agency_field)
      answer.update!(submitted_answer: value.to_s, question_name_when_answered: agency_field.name)
    end
  end

  # Recreate from scratch each run so re-seeding refreshes labels and link state.
  Person.where("email LIKE ? OR email LIKE ?",
    "orgchip.demo.%@seed.example.com", "affdemo.%@seed.example.com").find_each(&:destroy)

  # Each scenario => one registrant. :orgs link real orgs (→ chip shows links);
  # :agency stores a submitted name. A typed name matching an existing org is linked
  # (as registration does), so "Pending" only shows for names not among the linked
  # orgs — on its own (case 3) or alongside linked orgs (case 5). "None" = nothing typed.
  # Case 8 is the stale edge case: a typed name that matches an existing org but was
  # never linked (e.g. the org was created after the person registered) — it reads as
  # "Pending", and the editor offers that org as a one-click match to select.
  scenarios = [
    { last: "1 Linked one org",       orgs: demo_orgs.first(1) },
    { last: "2 Linked three orgs",    orgs: demo_orgs.first(3) },
    { last: "3 Pending no match",     agency: "Riverside Healing Arts Collective" },
    { last: "4 Matched name auto-linked", orgs: demo_orgs.first(1), agency: matched_org&.name },
    { last: "5 Mixed linked + pending", orgs: demo_orgs.first(1), agency: "Westview Community Healing" },
    { last: "6 None blank typed",     agency: "" },
    { last: "7 None nothing typed" },
    { last: "8 Pending matches existing org", agency: matched_org&.name }
  ]

  scenarios.each_with_index do |scenario, i|
    person = Person.create!(
      email: "orgchip.demo.#{i + 1}@seed.example.com",
      first_name: "Org Demo",
      last_name: scenario[:last]
    )
    registration = EventRegistration.find_or_create_by!(event: facilitator_training, registrant: person) do |reg|
      reg.status = "registered"
    end

    Array(scenario[:orgs]).each { |org| link_org.call(registration, org) }
    submit_agency_name.call(registration, scenario[:agency]) if scenario.key?(:agency)
  end

  # --- Affiliation-status demo: two affiliations per org (a real job title plus the
  # Facilitator role that gates AWBW-active), plus the position typed on the form, so
  # the org-link editor's affiliation pills can be seen across their states. ---
  position_field = registration_form.form_fields.find_by(field_identifier: "agency_position")
  submit_field = ->(registration, field, value) do
    if field
      submission = FormSubmission.find_or_create_by!(person: registration.registrant, form: registration_form)
      answer = submission.form_answers.find_or_initialize_by(form_field: field)
      answer.update!(submitted_answer: value.to_s, question_name_when_answered: field.name)
    end
  end
  add_affiliation = ->(person, organization, title:, end_date: nil) do
    Affiliation.find_or_create_by!(person: person, organization: organization, title: title) do |aff|
      aff.start_date = Date.current - 1.year
      aff.end_date = end_date
    end
  end

  aff_org = demo_orgs.first
  other_org = demo_orgs[1] || demo_orgs.first

  aff_scenarios = [
    { last: "A1 Title matches form",      job: "Counselor", position: "Counselor", facilitator_end: nil },
    { last: "A2 Title differs from form", job: "Counselor", position: "Director",  facilitator_end: nil },
    { last: "A3 Facilitator inactive",    job: "Counselor", position: "Counselor", facilitator_end: Date.current - 1.month }
  ]

  aff_scenarios.each_with_index do |scenario, i|
    next unless aff_org
    person = Person.create!(email: "affdemo.#{i + 1}@seed.example.com", first_name: "Demo Affiliation", last_name: scenario[:last])
    registration = EventRegistration.find_or_create_by!(event: facilitator_training, registrant: person) { |reg| reg.status = "registered" }
    registration.event_registration_organizations.find_or_create_by!(organization: aff_org)
    add_affiliation.call(person, aff_org, title: scenario[:job])
    add_affiliation.call(person, aff_org, title: "Facilitator", end_date: scenario[:facilitator_end])
    submit_field.call(registration, agency_field, aff_org.name)
    submit_field.call(registration, position_field, scenario[:position])
  end

  # An affiliation to an org NOT linked to the registration → shows under the
  # registrant's "other affiliations" section.
  if aff_org && other_org
    person = Person.create!(email: "affdemo.4@seed.example.com", first_name: "Demo Affiliation", last_name: "A4 Other affiliation")
    registration = EventRegistration.find_or_create_by!(event: facilitator_training, registrant: person) { |reg| reg.status = "registered" }
    registration.event_registration_organizations.find_or_create_by!(organization: aff_org)
    add_affiliation.call(person, aff_org, title: "Facilitator")
    add_affiliation.call(person, other_org, title: "Board Member")
  end
end
