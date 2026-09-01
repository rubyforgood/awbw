# Several years of interleaved history for one person — trainings, memberships and
# affiliation edits — so the person History card and the admin activity timeline have
# something realistic to render. Targets the owner of the first affiliation.
#
# Ahoy lifecycle events are written directly rather than letting AhoyTrackable fire
# them, because the whole point is timestamps spread over past years.

affiliation = Affiliation.order(:id).first

if affiliation.nil?
  puts "Skipping affiliation history seed: no affiliations. Run db:seed:dev first."
elsif Ahoy::Event.where(resource_type: "Affiliation", resource_id: affiliation.id).where("time < ?", 1.year.ago).exists?
  puts "Skipping affiliation history seed (already seeded)"
else
  person = affiliation.person
  actor = person&.user || User.where(super_user: true).first

  if person.nil? || actor.nil?
    puts "Skipping affiliation history seed: affiliation ##{affiliation.id} has no person or no admin user."
  else
    puts "Building #{person.full_name}'s history around affiliation ##{affiliation.id}…"

    home_org = affiliation.organization
    second_org = Organization.where.not(id: home_org&.id).order(:id).first || home_org

    visits = Hash.new do |cache, year|
      cache[year] = Ahoy::Visit.create!(
        visit_token: SecureRandom.uuid, visitor_token: SecureRandom.uuid, user: actor,
        started_at: Time.zone.local(year, 6, 1, 9, 0), browser: "Chrome", device_type: "Desktop",
        city: "Los Angeles", country: "US", landing_page: "/people/#{person.id}/edit"
      )
    end

    track = ->(action, record, at, extra = {}) do
      Ahoy::Event.create!(
        visit: visits[at.year],
        user: actor,
        name: "#{action}.#{record.class.table_name.singularize}",
        resource_type: record.class.name,
        resource_id: record.id,
        properties: {
          resource_type: record.class.name,
          resource_id: record.id,
          resource_title: (record.try(:title).presence || record.try(:name).presence || record.id).to_s
        }.merge(extra),
        time: at
      )
    end

    changed = ->(pairs) { { changes: pairs.transform_values { |(before, after)| { before: before, after: after } } } }

    # Comments reach the person's History through PersonCommentAggregator, so they
    # only show when left on the person or a record that hangs off them.
    note = ->(subject, body, at, topic: nil) do
      comment = subject.comments.create!(body: body, topic: topic, created_by: actor, updated_by: actor)
      comment.update_columns(created_at: at, updated_at: at)
      # The note's body belongs in the Details column (like a real tracked comment),
      # not jammed into the Resource title.
      track.("create", comment, at, { resource_title: "Comment", "topic" => topic, "body" => body }.compact_blank)
      comment
    end

    training = ->(title, starts_on, status, organization) do
      event = Event.create!(
        title: title,
        description: "Two-day facilitator training.",
        start_date: starts_on.to_time(:utc) + 9.hours,
        end_date: starts_on.to_time(:utc) + 1.day + 16.hours,
        registration_close_date: starts_on.to_time(:utc) - 1.week,
        facilitator_training: true,
        published: true,
        created_by: actor,
        cost_cents: 25_000
      )
      registration = EventRegistration.create!(event: event, registrant: person, status: status)
      EventRegistrationOrganization.create!(event_registration: registration, organization: organization)
      registration.update_columns(created_at: starts_on - 6.weeks, updated_at: starts_on + 3.days)

      track.("create", registration, starts_on - 6.weeks, { resource_title: title })
      track.("update", registration, starts_on + 3.days,
             { resource_title: title }.merge(changed.({ "status" => [ "registered", status ] })))
      registration
    end

    email = ->(subject, body, at, kind: "manual_log") do
      Notification.create!(
        kind: kind, notification_type: 0,
        channel: "email", direction: "outgoing", recipient_role: "person",
        recipient_email: person.communications_email, email_subject: subject, email_body_text: body,
        sender: actor, delivered_at: at
      ).update_columns(created_at: at, updated_at: at)
    end

    year = ->(n) { Date.current - n.years }

    # ── 7 years ago: first training, becomes a facilitator ───────────────────
    first_registration = training.("Facilitator Training: Foundations", year.(7), "attended", second_org)
    note.(first_registration, "Travelled in from out of state; covered by a partial scholarship.",
          year.(7) + 1.day, topic: "Registration")
    email.("Welcome to the AWBW facilitator community",
           "Congratulations on completing your facilitator training.", year.(7) + 3.days)

    first_facilitator = Affiliation.create!(
      person: person, organization: second_org, title: "Facilitator", start_date: year.(7) + 2.days
    )
    track.("create", first_facilitator, year.(7) + 2.days)
    note.(first_facilitator, "Minted from the Foundations training roster.", year.(7) + 2.days)

    # ── 6 years ago: first membership year, paid ─────────────────────────────
    subscription = person.memberships.create!
    subscription.update_columns(created_at: year.(6), updated_at: year.(6))
    track.("create", subscription, year.(6), { resource_title: "Membership" })

    [ 6, 4, 3, 0 ].each_with_index do |years_ago, index|
      invoice = subscription.membership_invoices.create!(
        start_date: year.(years_ago), cost_cents: Membership::ANNUAL_COST_CENTS
      )
      invoice.update_columns(created_at: year.(years_ago), updated_at: year.(years_ago))

      # MembershipInvoice isn't one of the person's tracked resources, so the renewal
      # shows as an update to the membership itself.
      unless index.zero?
        track.("update", subscription, year.(years_ago),
               { resource_title: "Membership" }.merge(changed.({ "membership_invoices" => [ index, index + 1 ] })))
      end

      next if index == 3 # current year left unpaid so the badge shows something owing

      paid_at = year.(years_ago) + (index == 2 ? 70 : 9).days
      payment = CashPayment.create!(
        person: person, amount_cents: Membership::ANNUAL_COST_CENTS,
        amount_cents_remaining: Membership::ANNUAL_COST_CENTS, currency: "usd"
      )
      payment.update_columns(created_at: paid_at, updated_at: paid_at)
      Allocation.create!(source: payment, allocatable: invoice, amount: Membership::ANNUAL_COST_CENTS)
      track.("create", payment, paid_at, { resource_title: "Membership dues #{year.(years_ago).year}" })
    end

    # ── 5 years ago: takes on a job title alongside the facilitator row ──────
    job = Affiliation.create!(person: person, organization: second_org, title: "Program Coordinator")
    track.("create", job, year.(5))
    note.(job, "Took on the Program Coordinator role alongside facilitating.", year.(5))
    note.(person, "Promoted internally — worth checking which affiliation should be primary.",
          year.(5) + 2.days, topic: "Profile")

    # ── 4 years ago: signs up for a refresher and doesn't show ───────────────
    no_show_registration = training.("Facilitator Training: Refresher", year.(4), "no_show", second_org)
    note.(no_show_registration, "Called the morning of to say they couldn't make it.",
          year.(4) + 1.day, topic: "Attendance")
    first_facilitator.update_columns(end_date: first_facilitator.start_date, inactive: true)
    track.("update", first_facilitator, year.(4) + 5.days,
           changed.({ "end_date" => [ nil, first_facilitator.start_date.to_s ], "inactive" => [ false, true ] }))
    note.(first_facilitator, "Ended after the refresher no-show; reinstate if they complete a later training.",
          year.(4) + 5.days)

    # ── 2 years ago: completes a training again, affiliation comes back ──────
    return_registration = training.("Facilitator Training: Trauma-Informed Practice", year.(2), "attended", second_org)
    note.(return_registration, "Back after two years away; asked about co-facilitating.",
          year.(2) + 1.day, topic: "Attendance")
    first_facilitator.update_columns(end_date: nil, inactive: false)
    track.("update", first_facilitator, year.(2) + 4.days,
           changed.({ "end_date" => [ first_facilitator.start_date.to_s, nil ], "inactive" => [ true, false ] }))
    note.(first_facilitator, "Reactivated after the Trauma-Informed Practice training.", year.(2) + 4.days)
    email.("Your facilitator affiliation is active again",
           "We've reactivated your facilitator affiliation following the training.", year.(2) + 4.days)

    # ── 1 year ago onward: edits to the affiliation this seed hangs off ──────
    track.("create", affiliation, affiliation.start_date.to_time + 10.hours)
    note.(affiliation, "Joined the #{home_org&.name} roster.", affiliation.start_date.to_time + 10.hours)

    track.("update", affiliation, 8.months.ago,
           changed.({ "title" => [ "Facilitator", affiliation.title ] }))
    track.("update", affiliation, 5.months.ago,
           changed.({ "primary_contact" => [ false, true ] }))
    note.(affiliation, "Now the primary contact for the organization.", 5.months.ago)
    track.("update", affiliation, 2.months.ago,
           changed.({ "start_date" => [ (affiliation.start_date + 1.month).to_s, affiliation.start_date.to_s ] }))
    note.(affiliation, "Corrected the start date against the training roster.", 2.months.ago)
    note.(person, "Confirmed the corrected dates by phone.", 6.weeks.ago, topic: "Profile")

    puts "  #{person.full_name}: #{person.event_registrations.count} registrations, " \
         "#{person.affiliations.count} affiliations, #{subscription.membership_invoices.count} membership years, " \
         "#{PersonCommentAggregator.new(person).comments.count} comments, " \
         "#{Analytics::PersonActivityEvents.new(person).count} activity events"
  end
end
