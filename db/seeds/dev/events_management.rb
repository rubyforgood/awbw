# Events management seeds (dev-only) - run on their own via `rake db:seed:events_management`,
# or as part of `rake db:seed:dev`. Creates the standalone registration/scholarship forms, the
# dev events that share them, event registrations for named scenarios, and form submissions.
# Named people are looked up when present (e.g. after `rake db:seed:people_profiles`).

# Faker is installed but not auto-required on staging, where the app runs as
# RAILS_ENV=production and Bundler.require only loads the production group.
require "faker"

puts "Creating standalone registration forms…"
unless Form.standalone.exists?(name: "Training Registration Form")
  # Sections are built in this order (not the canonical SECTIONS order) so the
  # seeded form reads top-to-bottom like the real AWBW Facilitator Training form:
  # Your Information → Mailing Address → Your Organization → Participant
  # Information → About You → Payment → Consent. The CE and "Additional forms"
  # magic questions are appended below and slotted into place by reorder.
  FormBuilderService.new(
    name: "Training Registration Form",
    sections: %i[person_identifier person_contact_info professional_info person_background marketing payment consent],
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

unless Form.standalone.find_by(role: "continuing_education")
  FormBuilderService.new(
    name: "Continuing Education Request",
    sections: %i[continuing_education],
    role: "continuing_education"
  ).call
end

puts "Creating Events with shared forms…"
admin_user = User.find_by(email: "umberto.user@example.com")
registration_form = Form.standalone.find_by!(role: "registration")
scholarship_form = Form.standalone.find_by!(role: "scholarship")
bulk_payment_form = Form.standalone.find_by!(role: "bulk_payment")
continuing_education_form = Form.standalone.find_by!(role: "continuing_education")

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

# The two "Your goals" essays carry a 250-word minimum on the real form. Set it
# on the seeded scholarship form so the public form shows the "Minimum of 250
# words" hint and enforces it on submit. Idempotent: only sets when not already set.
scholarship_form.form_fields
  .where(field_identifier: %w[impact_description implementation_plan], min_words: [ nil, 0 ])
  .update_all(min_words: 250)

# The real scholarship form heads its first section "Partial Scholarship
# Application" (see the scholarship screenshots). Idempotent — only renames the
# default header.
scholarship_form.form_fields
  .where(answer_type: :group_header, name: "Scholarship Application")
  .update_all(name: "Partial Scholarship Application")

# Rename the generic section headers FormBuilderService creates to the AWBW
# Facilitator Training wording, and add the subtitles shown on the real form.
# Idempotent: each rename only matches the default name, so a re-seed (or an admin
# edit) is left alone.
rename_registration_header = ->(from, to, subtitle: nil) do
  header = registration_form.form_fields.find_by(answer_type: :group_header, name: from)
  header&.update!(name: to, subtitle: subtitle)
end
rename_registration_header.call("Contact Information", "Your Information")
rename_registration_header.call("Mailing Address", "Primary Mailing Address",
                                subtitle: "For mailing raffle prizes, incentives, and important announcements")
rename_registration_header.call("Organization Information", "Your Organization",
                                subtitle: "If your organization has a website, please put your organization name as it appears on the website. " \
                                          "If you're not associated with an organization, please provide a name for your art program.")
rename_registration_header.call("Professional Information", "Participant Information")
rename_registration_header.call("Background Information", "About You")

# The real form folds the "How did you hear" / "What motivated you" questions in
# under the "About You" heading, with no separate Marketing header and no
# "interested in learning more?" question. Drop both so the seeded form matches.
registration_form.form_fields.where(answer_type: :group_header, name: "Marketing").destroy_all
registration_form.form_fields.where(field_identifier: "interested_in_more").destroy_all

# Match the public AWBW form's field set, labels, and order (see the registration
# screenshots): it labels the primary email "Primary Email", omits the optional
# Preferred Nickname / Pronouns questions, and lists "What motivated you" before
# "How did you hear". Idempotent — each clause only matches the default state.
registration_form.form_fields
  .where(field_identifier: "primary_email", name: "Email").update_all(name: "Primary Email")
registration_form.form_fields.where(field_identifier: %w[nickname pronouns]).destroy_all

motivation_field = registration_form.form_fields.find_by(field_identifier: "training_motivation")
referral_field = registration_form.form_fields.find_by(field_identifier: "referral_source")
if motivation_field && referral_field && motivation_field.position > referral_field.position
  motivation_position = motivation_field.position
  motivation_field.update_column(:position, referral_field.position)
  referral_field.update_column(:position, motivation_position)
end

# The real form notes the payment timing under the "Payment Information" heading.
registration_form.form_fields
  .where(answer_type: :group_header, name: "Payment Information", subtitle: [ nil, "" ])
  .update_all(subtitle: "Payments are due no more than three weeks after your registration date. " \
                        "Training details will be sent after payments are received.")

# The "Additional forms" question: a multi-select whose checked options drive the
# resulting registration's invoice_requested / w9_requested flags (see
# EventRegistrationServices::PublicRegistration). The digital ticket reads those
# flags to surface the matching downloads. Seeded onto its own section, like the
# CE question above, so the form builder's add/remove-section logic leaves it
# alone, and carrying the well-known field_identifier the service keys off. The
# W-9/Invoice option names must match the service's ADDITIONAL_FORMS_* constants;
# "No forms needed" is an inert opt-out the service ignores.
additional_forms_identifier = EventRegistrationServices::PublicRegistration::ADDITIONAL_FORMS_IDENTIFIER
if registration_form.form_fields.where(field_identifier: additional_forms_identifier).none?
  next_position = (registration_form.form_fields.maximum(:position) || 0) + 1
  registration_form.form_fields.create!(
    name: "Additional forms",
    answer_type: :group_header,
    status: :active,
    position: next_position,
    required: false,
    section: "additional_forms",
    visibility: :always_ask
  )
  additional_forms_field = registration_form.form_fields.create!(
    name: "Do you need either of the following?",
    answer_type: :multi_select_checkbox,
    status: :active,
    position: next_position + 1,
    required: false,
    field_identifier: additional_forms_identifier,
    section: "additional_forms",
    visibility: :always_ask,
    width: :full,
    subtitle: "If selected, these will be available on your digital registration ticket."
  )
  [
    EventRegistrationServices::PublicRegistration::ADDITIONAL_FORMS_W9,
    EventRegistrationServices::PublicRegistration::ADDITIONAL_FORMS_INVOICE,
    "No forms needed"
  ].each_with_index do |opt, idx|
    ao = AnswerOption.find_or_create_by!(name: opt) { |a| a.position = idx }
    additional_forms_field.form_field_answer_options.create!(answer_option: ao)
  end
end

# Renumber the form's fields so the appended CE block sits between "About You" and
# "Payment Information", and "Additional forms" sits between payment and consent —
# the order the real form uses. Idempotent: re-running lands on the same order.
registration_section_order = %w[
  person_identifier person_contact_info professional background marketing
  payment additional_forms consent
]
registration_section_rank = registration_section_order.each_with_index.to_h
registration_form.form_fields.reorder(:position).to_a.each_with_index
  .sort_by { |field, index| [ registration_section_rank.fetch(field.section, registration_section_rank.size), index ] }
  .each_with_index { |(field, _index), position| field.update_column(:position, position + 1) }

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
  event.update!(start_date: start_date, end_date: end_date, registration_close_date: registration_close, cost_cents: cost_cents, facilitator_training: title.match?(/training/i))

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

  # Materialize the built-in callouts (payment, CE hours, art supplies, …) as
  # editable rows, exactly as creating an event through the admin form does. They
  # seed hidden by default; the blocks below fill in and publish the demo copy on
  # the trainings. Idempotent, so re-seeding never clobbers.
  BuiltinCallouts.seed(event)
end

# The flagship training runs on Zoom — drive the platform from event settings so
# it shows as a badge in the public registration header (rather than living in the
# shared form header). It also turns on the structured "at a glance" details panel
# and carries the free-form qualifiers (hint_dates / hint_times / hint_registration_cost)
# so the seeded data demonstrates those grey parentheticals on its registration
# page. force-set on re-seed, mirroring the date/cost refresh above.
Event.find_by(title: "AWBW Facilitator Training")&.update!(
  videoconference_url: "https://awbw-org.zoom.us/j/88285411273",
  videoconference_label: "Zoom",
  videoconference_passcode: "awbwmarch",
  autoshow_registration_details: true,
  hint_dates: "must attend both days",
  hint_times: "both days",
  hint_registration_cost: "due within 3 weeks of registration"
)

# Un-gate a published videoconference callout on events that have a link, so its
# card stays reachable before payment (it's the doorway to the videoconference
# page, which gates the join details itself). Only when already published — don't
# force-publish an opted-out callout. force-set on re-seed.
Event.where.not(videoconference_url: [ nil, "" ]).find_each do |vc_event|
  vc = vc_event.registration_ticket_callouts.find_by(builtin_key: "videoconference")
  vc.update!(payment_access_gated: false) if vc&.published?
end

# Seed the "Before you attend" details — the materials/art-supply info that used to
# live in a long confirmation email and that registrants routinely missed. Shown on
# its own ticket-linked page (and via the prominent amber call-out on the ticket).
# A custom label demonstrates that the heading is admin-editable. Only set when
# blank so admin edits survive a re-seed.
flagship = Event.find_by(title: "AWBW Facilitator Training")

# Make the flagship training the admin's favorite event so the admin dashboard
# has a sensible default highlighted event after seeding.
admin_user.update!(favorite_event: flagship) if admin_user && flagship

# Add a published "Art supplies & what to bring" custom callout on the flagship
# training so the demo ticket links to a populated page. This is no longer a
# built-in callout, so the seed authors it like any admin-created one. Idempotent:
# only created when the event doesn't already have it, so admin edits survive a re-seed.
if flagship && flagship.registration_ticket_callouts.custom.find_by(title: "Art supplies & what to bring").nil?
  flagship.registration_ticket_callouts.create!(
    title: "Art supplies & what to bring",
    subtitle: "Important info for this event — please read",
    callout_type: "reference",
    icon_class: "fa-solid fa-palette",
    color_class: "blue",
    hidden: false,
    description: <<~HTML.strip)
    <p>Thank you for registering to join us for AWBW's Art Facilitator Training!</p>
    <p>Below you'll find information about the art supplies used in each of the five hands-on workshops included in the training, along with optional printable workshop worksheets. We're sharing these materials in advance in case you'd like to gather supplies or print resources ahead of time.</p>
    <p>You will receive additional training information as we get closer to the training dates.</p>
    <p>Have a question? <a href="/contact_us">Reach out through our contact form</a> and we'll be happy to help.</p>
    <p>We will be facilitating five hands-on art workshops, all of which can be done with paper, writing utensils (crayons, colored pencils, markers, etc.) and scissors.</p>
    <ul>
      <li>You'll receive printable workshop worksheets once your training fees are paid — printing them is optional.</li>
      <li>You're welcome to use any art supplies you like: oil/chalk pastels, paints, watercolors, collage materials, etc.</li>
      <li>You may want a journal or lined paper for writing.</li>
    </ul>
    <p>The sections below, grouped by workshop, are <strong>optional</strong> supplies you may want on hand. We'll demonstrate how to use them during the training — tap a workshop to expand it.</p>
    <details>
      <summary>Workshop 1</summary>
      <ul>
        <li>Clear glass stones</li>
        <li>Pendant settings (cabochon settings and swivel hooks to hold the glass stones)</li>
        <li>Hole punch to create paper circles — we recommend a 1.25" circle punch</li>
        <li>Paper for circles — white and/or colored cardstock, or printmaking paper painted with acrylics</li>
        <li>Glue to adhere paper circles to the glass stones — we recommend Aleene's Clear Gel Tacky Glue</li>
        <li>Clear packing tape</li>
      </ul>
    </details>
    <details>
      <summary>Workshop 2</summary>
      <ul>
        <li>Rough &amp; Ready Shrinky Dink paper</li>
        <li>Permanent markers</li>
        <li>Colored pencils (we recommend Prismacolor)</li>
        <li>A hole punch (single or three-hole is fine)</li>
        <li>Thin ribbon or wire (1/8 in. or thinner)</li>
        <li>An oven to cook the shrink paper (a toaster oven — not a toaster — works well)</li>
      </ul>
    </details>
    <details>
      <summary>Workshop 3</summary>
      <ul>
        <li>A glue stick (used in workshops 3 &amp; 5)</li>
        <li>Scotch tape</li>
        <li>Two copies of the dice handout (sent after fees are paid), printed on cardstock</li>
      </ul>
    </details>
    <details>
      <summary>Workshop 4</summary>
      <ul>
        <li>Oil-based pastels (we recommend Cray-Pas)</li>
        <li>Card/heavy stock or watercolor paper</li>
        <li>Watercolors (we recommend Prang)</li>
        <li>Cups for water</li>
        <li>Paintbrush</li>
        <li>Painter's tape</li>
      </ul>
    </details>
    <details>
      <summary>Workshop 5</summary>
      <ul>
        <li>Card/heavy stock paper</li>
        <li>Collage materials</li>
      </ul>
    </details>
  HTML
end

# Fill in the "CE hours" details on the flagship training's materialized ce_hours
# callout — the continuing-education requirements, payment, and sign-in rules that
# used to live in a long CE confirmation email. Shown on its own ticket-linked page
# for registrants who requested CE credit. A custom title demonstrates that the
# heading is admin-editable. Only set when blank so admin edits survive a re-seed.
flagship_ce = flagship&.registration_ticket_callouts&.find_by(builtin_key: "ce_hours")
if flagship_ce && flagship_ce.description.blank?
  flagship_ce.update!(hidden: false, title: "Continuing education", description: <<~HTML.strip)
    <p>AWBW is approved by the <a href="https://www.camft.org/" target="_blank" rel="noopener">California Association of Marriage and Family Therapists (CAMFT)</a>, provider ##{ContinuingEducationRegistration::ACCREDITATION_PROVIDER_NUMBER}, to sponsor continuing education for LMFTs, LCSWs, LPCCs, and LEPs in California.</p>
    <p>While these CE hours are automatically accepted for professionals licensed in California, each state has its own licensing board requirements regarding CE provider approval. Participants outside of California are responsible for confirming whether these hours meet the requirements for their specific license and state.</p>
    <h3>Before the training</h3>
    <ul>
      <li>Provide your LMFT / LCSW / LPCC / LEP license number.</li>
      <li>Submit payment of $120 for CE hours before the training begins.</li>
    </ul>
    <h3>During the training</h3>
    <ul>
      <li>Sign in and out at the beginning and end of each day, and when returning from all breaks (including the hour-long meal break). A link to the sign-in sheet is emailed before the training.</li>
      <li>Keep your camera on at all times during the training.</li>
    </ul>
    <h3>After the training</h3>
    <ul>
      <li>Complete the CE Hours Training Evaluation. A link is emailed before the training.</li>
    </ul>
    <h3>Important notes</h3>
    <ul>
      <li>CE hours cannot be issued if payment is not received by the deadline, even if sign-in requirements are completed.</li>
      <li>If participation minutes indicate that fewer than 12 CE hours can be awarded, refunds are not issued.</li>
    </ul>
    <p>Email <a href="mailto:trainings@awbw.org" target="_blank" rel="noopener">trainings@awbw.org</a> if you have any questions.</p>
  HTML
end

# The trauma-informed training also offers CE hours, with the default title.
trauma = Event.find_by(title: "Facilitator Training: Trauma-Informed Art Practices")
trauma_ce = trauma&.registration_ticket_callouts&.find_by(builtin_key: "ce_hours")
if trauma_ce && trauma_ce.description.blank?
  trauma_ce.update!(hidden: false, description: <<~HTML.strip)
    <p>This training is approved by <a href="https://www.camft.org/" target="_blank" rel="noopener">CAMFT</a> (provider ##{ContinuingEducationRegistration::ACCREDITATION_PROVIDER_NUMBER}) for <strong>18 CE hours</strong> across its three days.</p>
    <ul>
      <li>Provide your license type and number at registration; a $25 CE processing fee applies.</li>
      <li>Daily sign-in/sign-out is required — CE hours are awarded for full attendance only.</li>
      <li>Complete the post-training evaluation to receive your certificate within three weeks.</li>
    </ul>
  HTML
end

# Seed example registration ticket callouts on the art workshop — admin-configured
# call-outs that show on the registration ticket and each link to their own page.
# Demonstrates both types (reference reading + an action), custom colours/icons, a
# subtitle, and a paid-only callout that stays hidden until the registration is paid.
# Idempotent: only seeded when the workshop has no callouts yet, so admin edits survive.
art_workshop = Event.find_by(title: "Mindful Art for Survivors Workshop")
if art_workshop && art_workshop.registration_ticket_callouts.custom.none?
  art_workshop.registration_ticket_callouts.create!(
    [
      {
        title: "What to bring",
        subtitle: "A short list of optional supplies",
        callout_type: "reference",
        color_class: "green",
        icon_class: "fa-solid fa-palette",
        position: 1,
        description: <<~HTML.strip
          <p>Everything is provided, but you're welcome to bring your own supplies if you'd like.</p>
          <ul>
            <li>A journal or sketchbook</li>
            <li>Your favourite pens, markers, or colored pencils</li>
            <li>A water bottle and anything that helps you feel comfortable</li>
          </ul>
        HTML
      },
      {
        title: "Studio location & parking",
        subtitle: "Getting here on the day",
        callout_type: "reference",
        color_class: "amber",
        icon_class: "fa-solid fa-location-dot",
        position: 2,
        description: <<~HTML.strip
          <p>The studio is on the second floor — take the elevator near the main entrance.</p>
          <p>Street parking is free after 10am. There is also a paid lot directly across the street.</p>
        HTML
      },
      {
        title: "Download your workbook",
        subtitle: "Available once your spot is paid",
        callout_type: "action",
        color_class: "blue",
        icon_class: "fa-solid fa-file-pdf",
        payment_access_gated: true,
        position: 3,
        description: <<~HTML.strip
          <p>Thanks for completing your payment! Your printable workbook is ready.</p>
          <p>Printing it is optional — we'll have copies available at the studio too.</p>
        HTML
      }
    ]
  )
end

# Reusable registration-ticket callout "components" drawn from the real AWBW
# facilitator-training emails. Each entry is one callout; events pick the subset
# they need from COMPONENT_CALLOUTS below. The flagship training shows all of
# them (so the ticket exercises every colour, icon, type, and the paid-only gate);
# other trainings mix and match a generic subset. `payment_access_gated` callouts stay
# hidden until the registration is paid. Idempotent: an event is only seeded when
# it has no callouts yet, so admin edits survive a re-seed.
# NOTE: These seeded admin RegistrationTicketCallouts are superseded by the
# code-defined MagicTicketCallouts (payment, CE, scholarship, art supplies, forms,
# handouts, portal, videoconference, FAQ, certificate), which now render on every
# ticket. The block below is kept for reference but disabled — remove the
# =begin/=end to re-enable seeded admin callouts.
=begin
component_callouts = {
  art_supply_info: {
    title: "Art supply info",
    subtitle: "Optional supplies for the five hands-on workshops",
    callout_type: "reference", color_class: "amber", icon_class: "fa-solid fa-palette",
    description: <<~HTML.strip
      <p>We'll facilitate five hands-on art workshops, all of which can be done with paper, writing utensils (crayons, colored pencils, markers, etc.) and scissors.</p>
      <ul>
        <li>Use any art supplies you like — oil/chalk pastels, paints, watercolors, collage materials, etc.</li>
        <li>You may want a journal or lined paper for writing.</li>
      </ul>
      <p>The list below, grouped by workshop, is <strong>optional</strong> — we'll demonstrate how to use everything at the training.</p>
      <ul>
        <li><strong>Workshop 1:</strong> clear glass stones; cabochon settings and swivel hooks; a 1" circle punch; white/colored cardstock or printmaking paper; Aleene's Clear Gel Tacky Glue; packing tape; scissors.</li>
        <li><strong>Workshop 2:</strong> Rough &amp; Ready Shrinky Dink paper; permanent markers; Prismacolor colored pencils; a hole punch; thin ribbon or wire; an oven (a toaster oven, not a toaster).</li>
        <li><strong>Workshop 3:</strong> a glue stick; scotch tape; two copies of the dice handout printed on cardstock.</li>
        <li><strong>Workshop 4:</strong> Cray-Pas oil pastels; card/heavy stock or watercolor paper; Prang watercolors; cups for water; a paintbrush; painter's tape.</li>
        <li><strong>Workshop 5:</strong> card/heavy stock paper; collage materials; tissue paper.</li>
      </ul>
    HTML
  },
  training_workshop_worksheets: {
    title: "Training workshop worksheets",
    subtitle: "Print these before the training (optional)",
    callout_type: "action", color_class: "blue", icon_class: "fa-solid fa-file-lines",
    payment_access_gated: true,
    description: <<~HTML.strip
      <p>You're welcome to print the 2-day training workshop worksheets to use as you create — printing is optional.</p>
      <p>Your worksheets are available now that your training fee is paid.</p>
    HTML
  },
  aha_moments_worksheet: {
    title: "AHA Moments worksheet",
    subtitle: "Capture your reflections as you create",
    callout_type: "action", color_class: "green", icon_class: "fa-solid fa-lightbulb",
    description: <<~HTML.strip
      <p>We encourage you to print the AHA Moments worksheet to capture your thoughts about how the art workshops may shift things for you personally — and how you might use them to serve others.</p>
    HTML
  },
  participation_requirements: {
    title: "Participation requirements",
    subtitle: "Both full days are required for certification",
    callout_type: "reference", color_class: "purple", icon_class: "fa-solid fa-certificate",
    description: <<~HTML.strip
      <p>Participating in <strong>both full training days</strong> (9am–4:30pm Pacific Time each day) is required to receive certification as an AWBW facilitator.</p>
      <p>If you're unable to attend both full days, please <a href="/contact_us">let us know</a> as soon as possible.</p>
    HTML
  },
  letter_to_supervisors: {
    title: "Letter to supervisors",
    subtitle: "Share to request release time",
    callout_type: "action", color_class: "blue", icon_class: "fa-solid fa-file-arrow-down",
    description: <<~HTML.strip
      <p>We recommend sharing a letter with your supervisor (if applicable) to request relief from other duties during the two training days — being fully relieved helps you stay present.</p>
      <p>The letter is available to download and share.</p>
    HTML
  },
  ce_hours: {
    title: "Continuing education (CE) hours",
    subtitle: "Requirements, fee, and sign-in rules",
    callout_type: "reference", color_class: "indigo", icon_class: "fa-solid fa-graduation-cap",
    description: <<~HTML.strip
      <p>Licensed LMFTs, LCSWs, LPCCs, and LEPs can earn up to <strong>12 Continuing Education hours</strong> for the training.</p>
      <ul>
        <li>Let us know by Monday, July 20 so we can send the required materials.</li>
        <li>CE hour fee: $120 ($10 per hour).</li>
        <li>You must be on time each day; payment is due by 9:00 AM PT on July 22.</li>
      </ul>
    HTML
  },
  add_to_calendar: {
    title: "Add to your calendar",
    subtitle: "Save both training days",
    callout_type: "action", color_class: "green", icon_class: "fa-solid fa-calendar-plus",
    description: <<~HTML.strip
      <p>Save both training days to your calendar so you don't miss a moment — you'll find an add-to-calendar link at the bottom of this ticket too.</p>
    HTML
  },
  self_care_engagement: {
    title: "Self-care & engagement",
    subtitle: "Be on your own device and care for yourself",
    callout_type: "reference", color_class: "rose", icon_class: "fa-solid fa-heart",
    description: <<~HTML.strip
      <p>Please log on at 8:50am Pacific Time so we can start promptly at 9am.</p>
      <ul>
        <li>This training is interactive — come ready to participate and connect.</li>
        <li>If possible, <strong>be on your own individual device</strong> and keep your camera on; you're welcome to turn it off for personal needs.</li>
        <li>It's important to <strong>practice self-care</strong> — have water, snacks, and whatever helps you feel comfortable nearby.</li>
      </ul>
    HTML
  },
  all_training_handouts: {
    title: "All training handouts",
    subtitle: "Agenda, worksheets, and resources in one place",
    callout_type: "action", color_class: "blue", icon_class: "fa-solid fa-folder-open",
    payment_access_gated: true,
    description: <<~HTML.strip
      <p>All of the handouts for the training — including the agenda for both days and the art workshop worksheets — are available in one place.</p>
    HTML
  },
  inviting_responding_sharing: {
    title: "Inviting & responding to sharing",
    subtitle: "Holding space in breakout rooms",
    callout_type: "reference", color_class: "purple", icon_class: "fa-solid fa-comments",
    description: <<~HTML.strip
      <p>Throughout the training you'll be invited to hold space, share, and witness others. This resource offers guidance on doing so with openness and care during breakout rooms.</p>
      <p>Sharing is part of the art — together we co-create a space where everyone feels supported.</p>
    HTML
  },
  training_agenda: {
    title: "Training agenda",
    subtitle: "What to expect across the two days",
    callout_type: "reference", color_class: "amber", icon_class: "fa-solid fa-calendar-days",
    description: <<~HTML.strip
      <p>Our agenda covers both training days, including an hour-long food break around 12:00pm PT each day.</p>
    HTML
  },
  zoom_connection_info: {
    title: "Zoom connection info",
    subtitle: "Join link, meeting ID, and passcode",
    callout_type: "action", color_class: "blue", icon_class: "fa-solid fa-video",
    payment_access_gated: true,
    description: <<~HTML.strip
      <p>Join us on Zoom for both training days. You'll find the join link in this ticket's videoconference section.</p>
      <ul>
        <li><strong>Meeting ID:</strong> 882 8541 1273</li>
        <li><strong>Passcode:</strong> awbwmarch</li>
      </ul>
      <p>Please update Zoom to the latest version beforehand to avoid delays getting in.</p>
    HTML
  },
  questions_next_steps: {
    title: "Questions & next steps",
    subtitle: "More details are on the way",
    callout_type: "reference", color_class: "gray", icon_class: "fa-solid fa-envelope",
    description: <<~HTML.strip
      <p>You'll receive more details as we get closer to the training dates.</p>
      <p>In the meantime, please <a href="/contact_us">reach out</a> with any questions — we're always happy to help. We look forward to creating and connecting with you!</p>
    HTML
  }
}

# The flagship training (event 1) gets every component; the trauma-informed
# training gets a generic subset that doesn't assume the five-workshop supplies.
callouts_by_event = {
  "AWBW Facilitator Training" => component_callouts.keys,
  "Facilitator Training: Trauma-Informed Art Practices" =>
    %i[participation_requirements letter_to_supervisors add_to_calendar self_care_engagement questions_next_steps]
}

callouts_by_event.each do |event_title, component_keys|
  event = Event.find_by(title: event_title)
  next unless event && event.registration_ticket_callouts.custom.none?

  component_keys.each_with_index do |key, i|
    event.registration_ticket_callouts.create!(component_callouts.fetch(key).merge(position: i + 1))
  end
end
=end

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
aisha_person = User.find_by(email: "aisha.user@example.com")&.person

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
# Amy: registered, with form submission, scholarship recipient, requested W-9 and invoice
# Maria Johnson: registered, with form submission (has user), requested an invoice
# Anna Garcia: attended, with form submission (has user)
# Mario Johnson: registered, no form submission (no user)
# Kim Davis: cancelled (has user)
# Aisha: registered, intends to pay — no payment recorded, but access is granted
#   so she can reach her training materials (the intends_to_pay scenario). Pairs
#   with Amy on this same event, who DOES have payments, for side-by-side review.
if facilitator_training
  facilitator_training.update!(ce_hours_offered: 12, ce_hours_cost_cents: 12_000)
  [
    { person: amy_person, status: "registered", scholarship_requested: true, w9_requested: true, invoice_requested: true, ce_credit_requested: true, ce_license_number: "LMFT 90210" },
    { person: maria_j, status: "registered", invoice_requested: true, ce_credit_requested: true, intends_to_pay: true },
    { person: anna_g, status: "attended", ce_credit_requested: true, intends_to_pay: true, ce_license_number: "LCSW 11223", ce_status: "issued" },
    { person: mario_j, status: "registered" },
    { person: kim_d, status: "cancelled" },
    { person: aisha_person, status: "registered", intends_to_pay: true }
  ].each do |data|
    next unless data[:person]
    registrations_data << data.merge(event: facilitator_training)
  end
end

# --- Trauma Training: extended form, scholarship ---
# Sarah Smith: registered with form (has user), requested an invoice
# Jessica Brown: registered with form, scholarship (has user)
# Angel Garcia: registered, no form (no user)
# Linda Williams: no_show (no user)
if trauma_training
  trauma_training.update!(ce_hours_offered: 18, ce_hours_cost_cents: 15_000)
  [
    { person: sarah_s, status: "registered", invoice_requested: true, ce_credit_requested: true, ce_license_number: "LPCC 44556" },
    { person: jessica_b, status: "registered", scholarship_requested: true, ce_credit_requested: true },
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

# --- People with multiple active affiliations — exercise a registration linked to
# one of the registrant's orgs (the org they registered with), not all of them ---
mariana_j = Person.find_by(first_name: "Mariana", last_name: "Johnson")
samuel_s = Person.find_by(first_name: "Samuel", last_name: "Smith")
lisa_wn = Person.find_by(first_name: "Lisa", last_name: "Williamson")
kim_dv = Person.find_by(first_name: "Kim", last_name: "Davidson")
sarah_d = Person.find_by(first_name: "Sarah", last_name: "Davis")

multi_affiliation_registrations = { mariana_j => youth_day, samuel_s => mindful_art,
  lisa_wn => virtual_session, kim_dv => family_day, sarah_d => roundtable }
multi_affiliation_registrations.each do |person, evt|
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

  registration = EventRegistration.find_or_initialize_by(event: data[:event], registrant: data[:person])
  registration.status = data[:status] || "registered" if registration.new_record?
  registration.scholarship_requested ||= data[:scholarship_requested] || false
  # Keep the request flags in sync on re-seed so the named scenarios survive an
  # existing DB (find_or_initialize no longer recreates these registrations).
  registration.w9_requested = data[:w9_requested] || false
  registration.invoice_requested = data[:invoice_requested] || false
  registration.intends_to_pay = data[:intends_to_pay] || false
  registration.save!

  # CE opt-in becomes a ContinuingEducationRegistration against the registrant's
  # license (a placeholder when no number is seeded). Hours come from the event.
  if data[:ce_credit_requested] && registration.continuing_education_registrations.none?
    license = ProfessionalLicense.find_or_create_for(person: data[:person], number: data[:ce_license_number])
    ce_registration = registration.continuing_education_registrations.create!(professional_license: license)
    # "issued" in the seed data means the CE certificate was delivered.
    ce_registration.mark_certificate_sent! if data[:ce_status] == "issued"
  end
end

# Connect each multi-affiliation registrant's registration to a single one of
# their orgs — mirroring a real registration, which links only the org submitted
# on the form, not every active affiliation.
multi_affiliation_registrations.each do |person, evt|
  next unless person && evt
  org = person.affiliations.active.first&.organization
  next unless org
  registration = EventRegistration.find_by(event: evt, registrant: person)
  registration&.event_registration_organizations&.find_or_create_by!(organization: org)
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

# --- Cross-event training attendance -----------------------------------------
# Give Amy and Aisha several *attended* facilitator trainings across different
# years so the cross-event "Training attendees" index shows them with more than
# one event (and the row's expand chevron). These are separate past-dated events
# so they don't disturb the flagship training's named scenarios above.
puts "Seeding multi-training attendance for Amy and Aisha…"
past_trainings = [
  { title: "Facilitator Training: Foundations 2023", abbreviation: "FT2023", start: Date.new(2023, 3, 14) },
  { title: "Facilitator Training: Advanced Practice 2024", abbreviation: "FT2024", start: Date.new(2024, 6, 9) },
  { title: "Facilitator Training: Community Care 2025", abbreviation: "FT2025", start: Date.new(2025, 5, 20) }
].map do |attrs|
  event = Event.find_or_create_by!(title: attrs[:title]) do |e|
    e.description = "Past facilitator training (seed demo)."
    e.rhino_description = e.description
    e.created_by = admin_user
    e.public_registration_enabled = false
    e.start_date = attrs[:start].to_time
    e.end_date = (attrs[:start] + 1).to_time
    e.registration_close_date = (attrs[:start] - 7).to_time
    e.cost_cents = 15_000
  end
  # Keep the schedule/flags current and deterministic on re-seed (find_or_create_by!
  # only sets attributes on create).
  event.update!(
    abbreviation: attrs[:abbreviation],
    start_date: attrs[:start].to_time,
    end_date: (attrs[:start] + 1).to_time,
    registration_close_date: (attrs[:start] - 7).to_time,
    cost_cents: 15_000,
    facilitator_training: true,
    published: true
  )
  event
end

# Amy attended all three; Aisha attended the two most recent — both land on the
# index with multiple trainings.
{ amy_person => past_trainings, aisha_person => past_trainings.last(2) }.each do |person, events|
  next unless person
  events.each do |evt|
    registration = EventRegistration.find_or_initialize_by(event: evt, registrant: person)
    registration.status = "attended"
    registration.save!
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
# WorkshopEnvironment (settings) tags. Public registration no longer collects these
# (the "Workshop settings" and "Client life experiences" questions were removed), but
# the charts are retained for historical data and admin-applied tags, so seed a
# deterministic spread here so older trainings' background charts aren't empty.
#
# These tags live on the Person, not per-registration, so anyone registered for the
# flagship "AWBW Facilitator Training" (event #1) would surface on its charts too.
# Keep event #1 clean by never tagging its registrants, and by stripping any such
# tags a prior seed left on them.
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

flagship_registrant_ids = facilitator_training&.event_registrations&.active&.pluck(:registrant_id) || []
CategorizableItem.joins(category: :category_type)
  .where(categorizable_type: "Person", categorizable_id: flagship_registrant_ids)
  .where(category_types: { name: [ "WorkshopEnvironment", "StoryPopulation" ] })
  .destroy_all

[ trauma_training, wellness_day, youth_day, mindful_art, virtual_session, roundtable, family_day ].compact.each do |evt|
  evt.event_registrations.active.includes(:registrant).each_with_index do |registration, i|
    person = registration.registrant
    next unless person
    next if flagship_registrant_ids.include?(person.id)

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
    [ amy_person, maria_j, anna_g, aisha_person ].compact.each do |person|
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

  pf = FormSubmission.create!(person: data[:person], form: data[:form], event: data[:event], role: "registration")

  # Fill in required text fields with sample data
  data[:form].form_fields.where(answer_type: [ :free_form_input_one_line, :free_form_input_paragraph ]).each do |field|
    # Organization Name + Position / Title are seeded later with org-matching values
    # (record_organization_answers), so leave them blank here.
    next if %w[agency_name agency_position].include?(field.field_identifier)

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

puts "Giving Amy a free-text \"Other\" answer on her Facilitator Training submission…"
# Demo data for the "Other" chip on the person profile + edit pages: a registrant
# who picked the "Other" option (folded into "Other: <text>") on a sector-backed
# field (Additional sectors). The free-text value can't be a Sector record, so it
# only surfaces via Person#other_sector_responses.
# Seeded before the professional-answer enrichment below so the additional_sectors
# value survives its "skip if already answered" guard. Idempotent.
if facilitator_training && amy_person
  amy_submission = FormSubmission.find_by(person: amy_person, form: facilitator_training.registration_form)
  if amy_submission
    {
      "additional_sectors" => "Other: Equine-assisted therapy"
    }.each do |identifier, value|
      field = amy_submission.form.form_fields.find_by(field_identifier: identifier)
      next unless field
      answer = amy_submission.form_answers.find_or_initialize_by(form_field: field)
      answer.update!(submitted_answer: value, question_name_when_answered: field.name)
    end
  end
end

puts "Recording professional answers (age group / sector) on registration submissions…"
# The Background page charts the registrants' age-group and sector registration
# answers. Public registration stores these as ", "-joined category / sector ids
# (see PublicRegistration#save_form_answers + assign_tags); seed them the same way
# so the charts have data. The age-group and primary-sector charts read the form
# answers; the All-sectors chart reads SectorableItem tags, so write both.
# Idempotent: skips a field already answered on a submission, and only enriches
# people who have a submission (so the "registered but didn't fill the form"
# scenarios stay answer-free).
age_range_categories = Category.age_ranges.published.order(:position, :name).to_a
# Exclude the catch-all "Other" sector: it's the free-text fallback registrants
# type into (surfaced via Person#other_sector_responses), not a selectable
# sector. Seeding it as a sector tag would list "Other" as a real sector.
selectable_sectors = Sector.published.excluding_other.order(:name).to_a

record_professional_answers = ->(submission, i) do
  person = submission.person
  form = submission.form

  # Primary age group is a single-select dropdown, so store one AgeRange category id.
  age = age_range_categories[i % age_range_categories.size] if age_range_categories.any?
  age_field = form.form_fields.find_by(field_identifier: "primary_age_group")
  if age_field && age && submission.form_answers.where(form_field: age_field).none?
    submission.form_answers.create!(form_field: age_field,
                                    submitted_answer: age.id.to_s,
                                    question_name_when_answered: age_field.name)
  end

  # Additional age groups are multi-select checkboxes, so store a couple of
  # ", "-joined AgeRange ids the way public registration does.
  additional_ages = age_range_categories.rotate(i + 1).reject { |category| category == age }.first(2)
  additional_age_field = form.form_fields.find_by(field_identifier: "additional_age_group")
  if additional_age_field && additional_ages.present? && submission.form_answers.where(form_field: additional_age_field).none?
    submission.form_answers.create!(form_field: additional_age_field,
                                    submitted_answer: additional_ages.map(&:id).join(", "),
                                    question_name_when_answered: additional_age_field.name)
  end

  sectors = selectable_sectors.empty? ? [] : [ selectable_sectors[i % selectable_sectors.size], selectable_sectors[(i + 4) % selectable_sectors.size] ].uniq
  primary_sector = sectors.first
  additional_sectors = sectors.drop(1)

  # Mirror the registration form's two sector fields: the single-select primary
  # sector dropdown and the multi-select additional sectors checkboxes.
  primary_field = form.form_fields.find_by(field_identifier: "primary_sector_single")
  if primary_field && primary_sector && submission.form_answers.where(form_field: primary_field).none?
    submission.form_answers.create!(form_field: primary_field,
                                    submitted_answer: primary_sector.id.to_s,
                                    question_name_when_answered: primary_field.name)
  end
  additional_field = form.form_fields.find_by(field_identifier: "additional_sectors")
  if additional_field && additional_sectors.present? && submission.form_answers.where(form_field: additional_field).none?
    submission.form_answers.create!(form_field: additional_field,
                                    submitted_answer: additional_sectors.map(&:id).join(", "),
                                    question_name_when_answered: additional_field.name)
  end

  # Tag the person with the same primary/additional split assign_tags applies, so
  # the All-sectors chart has data and the recipients page + profile crown a single
  # primary that matches the form. Idempotent (a person enriched once per event).
  person.tag_sectors(primary_ids: [ primary_sector&.id ].compact, additional_ids: additional_sectors.map(&:id))
  person.tag_age_groups(primary_ids: [ age&.id ].compact, additional_ids: additional_ages.map(&:id))
end

# Real orgs (minus the AWBW house org) to link registrations against and match on,
# plus a spread of plausible job titles for the "Position / Title" answer.
org_answer_orgs = Organization.where.not(name: "A Window Between Worlds").order(:name).to_a
job_titles = [ "Facilitator", "Program Director", "Counselor", "Art Therapist",
               "Case Manager", "Volunteer Coordinator", "Executive Director", "Social Worker" ]
# Plausible, domain-appropriate org names that intentionally do NOT match any seeded
# org, so a registrant typing one produces a realistic "Pending" mismatch chip.
unmatched_org_names = [ "Riverside Healing Arts Collective", "Westview Community Healing",
                        "Lakeside Survivor Support Network", "Cedar Grove Family Services",
                        "Harbor Light Crisis Center", "Meadowbrook Wellness Coalition" ]

# Give a registrant's submission the "Organization Name" + "Position / Title" answers
# the registrants page reads: link a real org to the registration and submit a name
# that USUALLY matches it, but every 4th enriched registrant types a different
# organization so the "Pending" mismatch chip has visible volume. The mismatch counter
# only advances when an org answer is actually written (registrants with submissions are
# sparse), so the ~1-in-4 ratio holds regardless of how many registrants are skipped.
# Idempotent: skips an already-answered field and reuses an existing linked org.
org_answer_index = 0
record_organization_answers = ->(registration, submission, i) do
  person = registration.registrant
  form = submission.form

  # A title on most submissions, but leave roughly one in five blank so dev data
  # exercises both registration/linking outcomes: a job + Facilitator affiliation
  # when a title was given, and a Facilitator-only affiliation when it wasn't.
  position_field = form.form_fields.find_by(field_identifier: "agency_position")
  if position_field && i % 5 != 4 && submission.form_answers.where(form_field: position_field).none?
    submission.form_answers.create!(form_field: position_field,
                                    submitted_answer: job_titles[i % job_titles.size],
                                    question_name_when_answered: position_field.name)
  end

  agency_field = form.form_fields.find_by(field_identifier: "agency_name")
  next unless agency_field && org_answer_orgs.any?
  next if submission.form_answers.where(form_field: agency_field).any?

  linked_org = registration.organizations.first
  unless linked_org
    linked_org = org_answer_orgs[i % org_answer_orgs.size]
    Affiliation.find_or_create_by!(person: person, organization: linked_org) do |aff|
      aff.title = job_titles[i % job_titles.size]
      aff.start_date = Date.current
    end
    registration.event_registration_organizations.find_or_create_by!(organization: linked_org)
  end

  mismatch = org_answer_index % 4 == 3
  typed_name = mismatch ? unmatched_org_names[org_answer_index / 4 % unmatched_org_names.size] : linked_org.name
  org_answer_index += 1
  submission.form_answers.create!(form_field: agency_field,
                                  submitted_answer: typed_name,
                                  question_name_when_answered: agency_field.name)
end

# Give the flagship cohort registration submissions so its Background charts have
# volume (named scenarios above are unchanged; the cohort are generic fill-ins).
if facilitator_training && (reg_form = facilitator_training.registration_form)
  facilitator_training.event_registrations.active.includes(:registrant).each do |registration|
    person = registration.registrant
    next unless person&.email.to_s.start_with?("facilitator.cohort.")
    FormSubmission.find_or_create_by!(person: person, form: reg_form, role: "registration") do |fs|
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
    record_organization_answers.call(registration, submission, i)
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

puts "Featuring scholarship recipients with shout-outs…"
# The recipients page "Shout outs" block features registrants the admin opted in
# (EventRegistration#shoutout) whose profile carries shout-out text
# (Person#shoutout_text). Seed people ship without either, so the block renders
# empty. Opt in each scholarship recipient on the data-rich trainings and give
# them realistic shout-out text — only filling blank text, so real data is
# preserved. update_columns skips validations/callbacks, fine for seed back-fill.
shoutout_texts = [
  "Grateful for the chance to bring trauma-informed art workshops to the survivors and children we serve.",
  "This training helps me give emergency-shelter families a creative way to begin rebuilding after abuse.",
  "Proud to run community healing circles for survivors across our historically underserved neighborhoods.",
  "Honored to deliver culturally responsive crisis intervention and long-term recovery programming.",
  "Art has become our community's safest room — thank you for helping us hold that space for all ages.",
  "Determined to keep survivor-led prevention work breaking cycles of violence where I live."
]

[ facilitator_training, trauma_training ].compact.each do |evt|
  EventDashboard.new(evt).scholarship_applicants.each_with_index do |person, i|
    person.update_columns(shoutout_text: shoutout_texts[i % shoutout_texts.size]) if person.shoutout_text.blank?
    evt.event_registrations.active.find_by(registrant: person)&.update_columns(shoutout: true)
  end
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
  # "Pending" only exists when the form has the Organization Name field,
  # which lives in the person_contact_info section the dev form otherwise omits.
  unless registration_form.form_fields.exists?(field_identifier: "agency_name")
    FormBuilderService.update_sections!(
      registration_form,
      (registration_form.sections || []).map(&:to_sym) | [ :person_contact_info ]
    )
  end
  agency_field = registration_form.form_fields.find_by(field_identifier: "agency_name")
  agency_position_field = registration_form.form_fields.find_by(field_identifier: "agency_position")

  # Real, existing orgs to link against / match on (skip the AWBW house org).
  demo_orgs = Organization.where.not(name: "A Window Between Worlds").order(:name).to_a
  matched_org = demo_orgs.first
  # A partial of the matched org's name (its words minus the first) shares words
  # with it but isn't an exact match — drives a fuzzy "Suggested matches" hit
  # (case 11). Nil when the org name is a single word (no partial to take).
  fuzzy_agency = matched_org&.name.to_s.split.length.to_i > 1 ? matched_org.name.split.drop(1).join(" ") : nil

  # Several orgs that share a word ("Riverside"), so typing just that word surfaces
  # a handful of fuzzy "Suggested matches" at once (case 9). find_or_create so
  # re-seeding doesn't pile up duplicates.
  active_status = OrganizationStatus.find_by(name: "Active")
  fuzzy_match_word = "Riverside"
  [
    "Riverside Counseling Center",
    "Riverside Family Services",
    "Riverside Trauma Recovery",
    "Riverside Youth Outreach",
    "Riverside Wellness Collective"
  ].each do |org_name|
    org = Organization.find_or_create_by!(name: org_name) { |o| o.organization_status = active_status }
    # Give each a location so the fuzzy "Suggested matches" list shows city/state.
    org.addresses.create!(street_address: "100 Demo Way", city: "Riverside", locality: "Riverside", state: "CA", zip_code: "92501", primary: true) if org.addresses.none?
  end

  link_org = ->(registration, organization) do
    Affiliation.find_or_create_by!(person: registration.registrant, organization: organization) do |aff|
      aff.title = "Facilitator"
      aff.start_date = Date.current
    end
    registration.event_registration_organizations.find_or_create_by!(organization: organization)
  end

  submit_agency_name = ->(registration, value) do
    submission = FormSubmission.find_or_create_by!(person: registration.registrant, form: registration_form, role: "registration", event: registration.event)
    if agency_field
      answer = submission.form_answers.find_or_initialize_by(form_field: agency_field)
      answer.update!(submitted_answer: value.to_s, question_name_when_answered: agency_field.name)
    end
  end

  # Recreate from scratch each run so re-seeding refreshes labels and link state.
  # Release any resource authorship first: resources.rb (which runs after this) can
  # credit these demo people, and Person#resources_as_author is restrict_with_error,
  # so the destroy below silently fails and the re-create hits the name/email
  # uniqueness validation. Clearing author_id here keeps the block idempotent.
  demo_people = Person.where("email LIKE ? OR email LIKE ?",
    "orgchip.demo.%@seed.example.com", "affdemo.%@seed.example.com")
  Resource.where(author_id: demo_people).update_all(author_id: nil)
  demo_people.find_each(&:destroy)

  # Each scenario => one registrant. :orgs link real orgs (→ chip shows links);
  # :agency stores a submitted name. A typed name matching an existing org is linked
  # (as registration does), so "Pending" only shows for names not among the linked
  # orgs — on its own (case 3) or alongside linked orgs (case 5). "None" = nothing typed.
  # Case 8 is the stale edge case: a typed name that matches an existing org but was
  # never linked (e.g. the org was created after the person registered) — it reads as
  # "Pending", and the editor offers that org as a one-click match to select.
  # Numbers are zero-padded so the registrants list (sorted by name) shows them in
  # order 01..11 rather than 1, 10, 11, 2, 3…
  scenarios = [
    { last: "01 Linked one org",       orgs: demo_orgs.first(1) },
    { last: "02 Linked three orgs",    orgs: demo_orgs.first(3) },
    { last: "03 Pending no match",     agency: "Riverside Healing Arts Collective" },
    { last: "04 Matched name auto-linked", orgs: demo_orgs.first(1), agency: matched_org&.name },
    { last: "05 Mixed linked + pending", orgs: demo_orgs.first(1), agency: "Westview Community Healing" },
    { last: "06 None blank typed",     agency: "" },
    { last: "07 None nothing typed" },
    { last: "08 Pending matches existing org", agency: matched_org&.name }
  ]
  # Case 9: a single word shared by several orgs — not an exact match, so it shows
  # a "Create and link" row plus a handful of orgs under fuzzy "Suggested matches".
  # Includes a job title so the submission detail shows a position too.
  scenarios << { last: "09 Fuzzy match suggestions", agency: fuzzy_match_word, position: "Lead Facilitator" }

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
    if scenario[:position].present? && agency_position_field
      submission = FormSubmission.find_or_create_by!(person: person, form: registration_form, role: "registration", event: registration.event)
      answer = submission.form_answers.find_or_initialize_by(form_field: agency_position_field)
      answer.update!(submitted_answer: scenario[:position], question_name_when_answered: agency_position_field.name)
    end
  end

  # Demo 10: a registrant with more than one registration-form submission, each
  # naming a different org we don't have — exercises the per-submission "View
  # submission #N" links and one "Create and link" row per distinct submitted org.
  if agency_field
    demo_multi = Person.create!(
      email: "orgchip.demo.10@seed.example.com",
      first_name: "Org Demo",
      last_name: "10 Multiple submissions"
    )
    EventRegistration.find_or_create_by!(event: facilitator_training, registrant: demo_multi) do |reg|
      reg.status = "registered"
    end
    [ "Greenfield Survivor Services", "Harbor Light Counseling" ].each do |org_name|
      submission = FormSubmission.create!(person: demo_multi, form: registration_form, event: facilitator_training, role: "registration")
      submission.form_answers.create!(form_field: agency_field, submitted_answer: org_name, question_name_when_answered: agency_field.name)
    end
  end

  # Demo 11: fuzzy matching AND multiple submissions together — two submissions,
  # each naming a partial of a different existing org. Exercises multiple "View
  # submission #N" links, a "Create and link" row per partial, and the fuzzy
  # "Suggested matches" list (driven by the first/primary submission).
  fuzzy_agency_2 = demo_orgs[1]&.name.to_s.split.length.to_i > 1 ? demo_orgs[1].name.split.drop(1).join(" ") : nil
  if agency_field && fuzzy_agency.present? && fuzzy_agency_2.present?
    demo_fuzzy_multi = Person.create!(
      email: "orgchip.demo.11@seed.example.com",
      first_name: "Org Demo",
      last_name: "11 Fuzzy + multiple submissions"
    )
    EventRegistration.find_or_create_by!(event: facilitator_training, registrant: demo_fuzzy_multi) do |reg|
      reg.status = "registered"
    end
    [ fuzzy_agency, fuzzy_agency_2 ].each do |org_name|
      submission = FormSubmission.create!(person: demo_fuzzy_multi, form: registration_form, event: facilitator_training, role: "registration")
      submission.form_answers.create!(form_field: agency_field, submitted_answer: org_name, question_name_when_answered: agency_field.name)
    end
  end

  # --- Affiliation-status demo: two affiliations per org (a real job title plus the
  # Facilitator role that gates AWBW-active), plus the position typed on the form, so
  # the org-link editor's affiliation pills can be seen across their states. ---
  position_field = registration_form.form_fields.find_by(field_identifier: "agency_position")
  submit_field = ->(registration, field, value) do
    if field
      submission = FormSubmission.find_or_create_by!(person: registration.registrant, form: registration_form, role: "registration", event: registration.event)
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

  # The two ways a single registration ends up with more than one org. A
  # registration no longer snapshots every affiliation, so multiple orgs are
  # always deliberate — these two demos show each path side by side.

  # A5: the registrant submitted one org on the form, then an admin linked a
  # second org by hand → two linked orgs but a single submission.
  if aff_org && other_org
    person = Person.create!(email: "affdemo.5@seed.example.com", first_name: "Demo Affiliation", last_name: "A5 Admin-linked second org")
    registration = EventRegistration.find_or_create_by!(event: facilitator_training, registrant: person) { |reg| reg.status = "registered" }
    submit_field.call(registration, agency_field, aff_org.name)
    link_org.call(registration, aff_org)
    # Admin adds the second org later — no matching submission (mirrors the
    # select/create_organization controller path: affiliation + connection).
    link_org.call(registration, other_org)
  end

  # A6: the registrant applied twice, each submission naming a different org →
  # two submissions, each adding its single org, so the registration links both.
  if aff_org && other_org
    person = Person.create!(email: "affdemo.6@seed.example.com", first_name: "Demo Affiliation", last_name: "A6 Applied twice, two orgs")
    registration = EventRegistration.find_or_create_by!(event: facilitator_training, registrant: person) { |reg| reg.status = "registered" }
    [ aff_org, other_org ].each do |org|
      submission = FormSubmission.create!(person: person, form: registration_form, event: facilitator_training, role: "registration")
      submission.form_answers.create!(form_field: agency_field, submitted_answer: org.name, question_name_when_answered: agency_field.name) if agency_field
      link_org.call(registration, org)
    end
  end
end
