require "rails_helper"

RSpec.describe AffiliationServices::ReconcilePerson do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }

  # A facilitator-training registration for `person` linking `organization`.
  def training_registration(status:, ended: true)
    event = create(:event, *(ended ? [ :ended ] : []), facilitator_training: true)
    reg = create(:event_registration, registrant: person, event: event, status: status)
    create(:event_registration_organization, event_registration: reg, organization: organization)
    reg
  end

  # A "Facilitator" affiliation for (person, organization) owned by `registration`.
  # Defaults to the training's own date, which is what the registration flow sets
  # (ADR-0001 D8) and what makes it "the row this training minted" (ADR-0003 D6).
  def owned_facilitator(registration:, start_date: nil)
    create(:affiliation,
           person: person,
           organization: organization,
           title: "Facilitator",
           start_date: start_date || registration.event.start_date.to_date,
           event_registration: registration)
  end

  def reconcile(registration, **options)
    described_class.call(person: person, organization: organization, event: registration.event, **options)
  end

  describe "deactivation" do
    it "deletes the row this training minted when the person never attended" do
      reg = training_registration(status: "no_show")
      affiliation = owned_facilitator(registration: reg)

      reconcile(reg)

      expect(Affiliation.exists?(affiliation.id)).to be(false)
    end

    %w[ incomplete_attendance cancelled ].each do |status|
      it "deletes the minted row when the only registration is #{status}" do
        reg = training_registration(status: status)
        affiliation = owned_facilitator(registration: reg)

        reconcile(reg)

        expect(Affiliation.exists?(affiliation.id)).to be(false)
      end
    end

    # `registered` after the event means nobody filled the roster in. Acting on it
    # would be acting on missing data.
    it "leaves a still-registered row alone and asks for an outcome instead" do
      reg = training_registration(status: "registered")
      affiliation = owned_facilitator(registration: reg)

      plan = described_class.new(person: person, organization: organization,
                                 event: reg.event, registration: reg).plan

      expect(plan.map(&:action)).to eq([ :noop ])
      expect(plan.first.reason).to eq(described_class::ATTENDANCE_NOT_RECORDED)

      reconcile(reg)
      expect(Affiliation.exists?(affiliation.id)).to be(true)
    end

    it "still says the training hasn't ended when it hasn't, rather than asking for an outcome" do
      reg = training_registration(status: "registered", ended: false)
      owned_facilitator(registration: reg, start_date: Date.current)

      plan = described_class.new(person: person, organization: organization,
                                 event: reg.event, registration: reg).plan

      expect(plan.first.reason).to eq(described_class::TRAINING_PENDING)
    end

    it "deletes it on the day a one-day training ends, with no reliance on the inactive flag" do
      event = create(:event, facilitator_training: true, start_date: 3.hours.ago,
                     end_date: 1.hour.ago, registration_close_date: 4.hours.ago)
      reg = create(:event_registration, registrant: person, event: event, status: "no_show")
      create(:event_registration_organization, event_registration: reg, organization: organization)
      affiliation = owned_facilitator(registration: reg, start_date: Date.current)

      reconcile(reg)

      expect(Affiliation.exists?(affiliation.id)).to be(false)
    end

    it "leaves the person's other organizations' affiliations alone" do
      reg = training_registration(status: "no_show")
      owned_facilitator(registration: reg)
      elsewhere = create(:affiliation, person: person, organization: create(:organization),
                                       title: "Facilitator", start_date: 1.year.ago.to_date)

      reconcile(reg)

      expect(elsewhere.reload).to be_active
    end

    it "leaves a job affiliation from the same registration alone" do
      reg = training_registration(status: "no_show")
      owned_facilitator(registration: reg)
      job = create(:affiliation, person: person, organization: organization, title: "Counselor",
                                 event_registration: reg)

      reconcile(reg)

      expect(Affiliation.exists?(job.id)).to be(true)
    end

    it "leaves an assumptive affiliation alone while its training is still upcoming" do
      reg = training_registration(status: "registered", ended: false)
      affiliation = owned_facilitator(registration: reg, start_date: Date.current)

      reconcile(reg)

      expect(affiliation.reload).to be_active
      expect(affiliation.end_date).to be_nil
    end

    it "leaves an unowned (hand-created) facilitator affiliation untouched" do
      reg = training_registration(status: "no_show")
      hand_created = create(:affiliation, person: person, organization: organization,
                            title: "Facilitator", start_date: 1.month.ago.to_date)

      reconcile(reg)

      expect(hand_created.reload).to be_active
      expect(hand_created.end_date).to be_nil
    end

    it "reconciles a hand-created affiliation when the caller opts in" do
      reg = training_registration(status: "no_show")
      hand_created = create(:affiliation, person: person, organization: organization,
                            title: "Facilitator", start_date: 1.month.ago.to_date)

      reconcile(reg, include_unowned: true)

      expect(hand_created.reload).not_to be_active
    end

    # The day before, not the day of: a row ending the same day another starts would
    # count on both and double the person in any report that totals a date.
    it "ends an older affiliation the day before the training, keeping the years it really facilitated" do
      reg = training_registration(status: "no_show")
      started_on = 2.years.ago.to_date
      hand_created = create(:affiliation, person: person, organization: organization,
                            title: "Facilitator", start_date: started_on)

      reconcile(reg, include_unowned: true)

      expect(hand_created.reload.end_date).to eq(reg.event.start_date.to_date - 1.day)
      expect(hand_created.start_date).to eq(started_on)
    end

    it "same-days an older affiliation that starts after the training rather than ending it before it began" do
      reg = training_registration(status: "no_show")
      later = create(:affiliation, person: person, organization: organization,
                     title: "Facilitator", start_date: Date.current)

      reconcile(reg, include_unowned: true)

      expect(later.reload.end_date).to eq(later.start_date)
    end
  end

  describe "the comment reconciliation leaves behind" do
    it "records why an older row was ended, and who did it" do
      user = create(:user, :admin)
      Current.user = user
      reg = training_registration(status: "no_show")
      older = create(:affiliation, person: person, organization: organization,
                                   title: "Facilitator", start_date: 2.years.ago.to_date)

      reconcile(reg, include_unowned: true)

      comment = older.reload.comments.last
      expect(comment.topic).to eq(described_class::COMMENT_TOPIC)
      expect(comment.body).to include("marked inactive by reconciliation")
      expect(comment.body).to include(reg.event.title)
      expect(comment.created_by).to eq(user)
    ensure
      Current.user = nil
    end

    # A deleted row takes its comments with it, so the trail for those lives in the
    # Ahoy destroy event instead — with the full attribute snapshot.
    it "leaves the deletion of a minted row in the activity log" do
      Current.user = create(:user, :admin)
      reg = training_registration(status: "no_show")
      affiliation = owned_facilitator(registration: reg)
      allow(Analytics::LifecycleBuffer).to receive(:push).and_call_original

      reconcile(reg)

      expect(Analytics::LifecycleBuffer).to have_received(:push)
        .with(hash_including(name: "destroy.affiliation",
                             properties: hash_including(resource_id: affiliation.id)))
    ensure
      Current.user = nil
    end

    it "records why a returning facilitator's new row appeared" do
      create(:affiliation, person: person, organization: organization, title: "Facilitator",
             start_date: Date.new(2023, 1, 1), end_date: Date.new(2024, 1, 1))
      reg = training_registration(status: "attended")

      described_class.call(person: person, organization: organization, event: reg.event,
                           registration: reg, include_unowned: true)

      fresh = person.affiliations.facilitators.active.where(organization: organization).last
      expect(fresh.comments.last.body).to include("Created by reconciliation")
    end

    it "distinguishes a row it ended from one an admin ended" do
      reg = training_registration(status: "no_show")
      admin_ended = create(:affiliation, person: person, organization: organization, title: "Facilitator",
                           start_date: 3.years.ago.to_date, end_date: 2.years.ago.to_date)

      plan = described_class.new(person: person, organization: organization, event: reg.event,
                                 registration: reg, include_unowned: true).plan

      expect(plan.map(&:reason)).to include(described_class::ALREADY_ENDED)
      expect(plan.map(&:reason)).not_to include(described_class::ALREADY_DEACTIVATED)
      expect(admin_ended.reload.end_date).to eq(2.years.ago.to_date)
    end
  end

  describe "a transfer out" do
    # Source registration transferred out to `destination_event`, with the org
    # carried onto the destination the way the transfer flow does.
    def transferred_out(destination_event:, link_org: organization)
      source = training_registration(status: "registered")
      destination = create(:event_registration, registrant: person, event: destination_event, status: "registered")
      create(:event_registration_organization, event_registration: destination, organization: link_org) if link_org
      destination.update!(transferred_from_registration: source)
      source.update!(status: "transferred_out")
      [ source, destination ]
    end

    let(:destination_event) do
      create(:event, facilitator_training: true, start_date: 3.months.from_now,
                     end_date: 3.months.from_now + 1.day,
                     registration_close_date: 2.months.from_now)
    end

    it "moves the open affiliation to the destination event and re-points its provenance" do
      source, destination = transferred_out(destination_event: destination_event)
      affiliation = owned_facilitator(registration: source)

      described_class.call(person: person, organization: organization, event: source.event,
                           registration: source, include_unowned: true)

      affiliation.reload
      expect(affiliation.start_date).to eq(destination_event.start_date.to_date)
      expect(affiliation.event_registration_id).to eq(destination.id)
      expect(affiliation.end_date).to be_nil
    end

    it "leaves an already-ended row alone and creates a fresh one at the destination" do
      source, destination = transferred_out(destination_event: destination_event)
      ended = create(:affiliation, person: person, organization: organization, title: "Facilitator",
                                   start_date: 3.years.ago.to_date, end_date: 2.years.ago.to_date)

      expect {
        described_class.call(person: person, organization: organization, event: source.event,
                             registration: source, include_unowned: true)
      }.to change { person.affiliations.facilitators.where(organization: organization).count }.by(1)

      expect(ended.reload.end_date).to eq(2.years.ago.to_date)
      fresh = person.affiliations.facilitators.where(organization: organization).order(:start_date).last
      expect(fresh.start_date).to eq(destination_event.start_date.to_date)
      expect(fresh.event_registration_id).to eq(destination.id)
    end

    it "reports rather than guesses when the destination hasn't been recorded" do
      source = training_registration(status: "registered")
      source.update!(status: "transferred_out")
      owned_facilitator(registration: source)

      plan = described_class.new(person: person, organization: organization, event: source.event,
                                 registration: source, include_unowned: true).plan

      expect(plan.map(&:action)).to eq([ :noop ])
      expect(plan.first.reason).to eq(described_class::TRANSFER_PENDING)
    end

    it "reports when the destination is linked to a different organization" do
      source, _destination = transferred_out(destination_event: destination_event, link_org: create(:organization))
      affiliation = owned_facilitator(registration: source)

      described_class.call(person: person, organization: organization, event: source.event,
                           registration: source, include_unowned: true)

      expect(affiliation.reload.start_date).to eq(source.event.start_date.to_date)
      expect(affiliation.event_registration_id).to eq(source.id)
    end

    it "records why the affiliation moved" do
      source, _destination = transferred_out(destination_event: destination_event)
      affiliation = owned_facilitator(registration: source)

      described_class.call(person: person, organization: organization, event: source.event,
                           registration: source, include_unowned: true)

      expect(affiliation.reload.comments.last.body).to include("transferred out of")
    end
  end

  describe "keeping / activating" do
    it "keeps the affiliation active when the person attended" do
      reg = training_registration(status: "attended")
      affiliation = owned_facilitator(registration: reg)

      reconcile(reg)

      expect(affiliation.reload).to be_active
      expect(affiliation.end_date).to be_nil
    end

    it "keeps active when the person no-showed one training but attended another for the same org" do
      no_show = training_registration(status: "no_show")
      affiliation = owned_facilitator(registration: no_show)
      training_registration(status: "attended")

      reconcile(no_show)

      expect(affiliation.reload).to be_active
    end

    it "records a return as a NEW affiliation, leaving the ended one ended" do
      reg = training_registration(status: "attended")
      ended = owned_facilitator(registration: reg, start_date: 1.month.ago.to_date)
      ended.update!(end_date: ended.start_date)
      expect(ended.reload).not_to be_active

      expect { described_class.call(person: person, organization: organization, event: reg.event, registration: reg) }
        .to change { person.affiliations.facilitators.where(organization: organization).count }.by(1)

      expect(ended.reload.end_date).to eq(ended.start_date)
      expect(person.affiliations.facilitators.active.where(organization: organization).count).to eq(1)
    end

    it "reopens the row it ended here once the person is marked attended, rather than adding a second" do
      reg = training_registration(status: "no_show")
      older = create(:affiliation, person: person, organization: organization, title: "Facilitator",
                                   start_date: 2.years.ago.to_date)

      described_class.call(person: person, organization: organization, event: reg.event,
                           registration: reg, include_unowned: true)
      expect(older.reload.end_date).to be_present

      reg.update!(status: "attended")

      expect {
        described_class.call(person: person, organization: organization, event: reg.event,
                             registration: reg, include_unowned: true)
      }.not_to change { person.affiliations.facilitators.where(organization: organization).count }

      expect(older.reload.end_date).to be_nil
      expect(older).to be_active
      expect(person.affiliations.facilitators.active.where(organization: organization).count).to eq(1)
    end

    # The end date is derived from the event's timestamp in the ambient zone, and a
    # request runs in the signed-in user's — so the writer and the reader routinely
    # disagree by a calendar day.
    it "still recognises its own ending when read back in another time zone" do
      event = create(:event, facilitator_training: true, start_date: 14.days.ago.change(hour: 5),
                             end_date: 12.days.ago.change(hour: 17), registration_close_date: 20.days.ago)
      reg = create(:event_registration, registrant: person, event: event, status: "no_show")
      create(:event_registration_organization, event_registration: reg, organization: organization)
      create(:affiliation, person: person, organization: organization, title: "Facilitator",
                           start_date: 2.years.ago.to_date)
      described_class.call(person: person, organization: organization, event: event,
                           registration: reg, include_unowned: true)
      reg.update!(status: "attended")

      # Loaded inside the zone: an already-materialized timestamp keeps the zone it
      # was first read in, which is not how a request sees it.
      plan = Time.use_zone("Hawaii") do
        described_class.new(person: person, organization: organization, event: Event.find(event.id),
                            registration: reg, include_unowned: true).plan
      end

      expect(plan.map(&:action)).to eq([ :reactivate ])
    end

    it "plans that reopen as :reactivate, with no create alongside it" do
      reg = training_registration(status: "no_show")
      create(:affiliation, person: person, organization: organization, title: "Facilitator",
                           start_date: 2.years.ago.to_date)
      described_class.call(person: person, organization: organization, event: reg.event,
                           registration: reg, include_unowned: true)
      reg.update!(status: "attended")

      plan = described_class.new(person: person, organization: organization, event: reg.event,
                                 registration: reg, include_unowned: true).plan

      expect(plan.map(&:action)).to eq([ :reactivate ])
    end

    # Same end date, but nobody's reconciliation put it there — so it records a real
    # lapse and the return belongs in its own row.
    it "does not reopen a row an admin ended, even when the date matches" do
      reg = training_registration(status: "attended")
      create(:affiliation, person: person, organization: organization, title: "Facilitator",
                           start_date: 3.years.ago.to_date,
                           end_date: reg.event.start_date.to_date - 1.day)

      plan = described_class.new(person: person, organization: organization, event: reg.event,
                                 registration: reg, include_unowned: true).plan

      expect(plan.map(&:action)).to contain_exactly(:noop, :create)
      expect(plan.map(&:reason)).to include(described_class::LAPSED)
    end

    it "keeps the lapse visible instead of swallowing it into one unbroken stretch" do
      lapsed = create(:affiliation, person: person, organization: organization, title: "Facilitator",
                      start_date: Date.new(2023, 1, 1), end_date: Date.new(2024, 1, 1))
      reg = training_registration(status: "attended")

      described_class.call(person: person, organization: organization, event: reg.event,
                           registration: reg, include_unowned: true)

      expect(lapsed.reload.end_date).to eq(Date.new(2024, 1, 1))
      expect(organization.reload.facilitator_status_on(Date.new(2025, 1, 1))).to eq(:reinstated)
    end

    it "plans no action on a lapsed row, explaining why" do
      create(:affiliation, person: person, organization: organization, title: "Facilitator",
             start_date: Date.new(2023, 1, 1), end_date: Date.new(2024, 1, 1))
      reg = training_registration(status: "attended")

      plan = described_class.new(person: person, organization: organization, event: reg.event,
                                 registration: reg, include_unowned: true).plan

      expect(plan.map(&:action)).to contain_exactly(:noop, :create)
      expect(plan.map(&:reason)).to include(described_class::LAPSED)
    end
  end

  describe "creating" do
    it "creates the missing facilitator affiliation for an attendee" do
      reg = training_registration(status: "attended")

      expect { described_class.call(person: person, organization: organization, event: reg.event, registration: reg) }
        .to change { person.affiliations.facilitators.where(organization: organization).count }.by(1)
    end

    it "proposes nothing when the caller passes no registration to own the new row" do
      reg = training_registration(status: "attended")

      plan = described_class.new(person: person, organization: organization, event: reg.event).plan

      expect(plan).to be_empty
    end
  end

  describe "idempotence" do
    it "does not move an older row's end date on a second run" do
      reg = training_registration(status: "no_show")
      older = create(:affiliation, person: person, organization: organization,
                                   title: "Facilitator", start_date: 2.years.ago.to_date)

      reconcile(reg, include_unowned: true)
      first = older.reload.end_date
      reconcile(reg, include_unowned: true)

      expect(older.reload.end_date).to eq(first)
    end

    it "has nothing left to do once the minted row is gone" do
      reg = training_registration(status: "no_show")
      owned_facilitator(registration: reg)

      reconcile(reg)

      expect { reconcile(reg) }.not_to change { Affiliation.count }
    end
  end

  describe "#plan (dry run)" do
    it "reports :delete for the minted row without writing" do
      reg = training_registration(status: "no_show")
      affiliation = owned_facilitator(registration: reg)

      plan = described_class.new(person: person, organization: organization, event: reg.event).plan

      expect(plan.map(&:action)).to eq([ :delete ])
      expect(Affiliation.exists?(affiliation.id)).to be(true)
    end

    it "reports :deactivate for an older row, which is ended rather than deleted" do
      reg = training_registration(status: "no_show")
      older = create(:affiliation, person: person, organization: organization,
                                   title: "Facilitator", start_date: 2.years.ago.to_date)

      plan = described_class.new(person: person, organization: organization,
                                 event: reg.event, include_unowned: true).plan

      expect(plan.map(&:action)).to eq([ :deactivate ])
      expect(older.reload).to be_active
    end

    it "reports the reason a row needs no action" do
      reg = training_registration(status: "attended")
      owned_facilitator(registration: reg)

      plan = described_class.new(person: person, organization: organization, event: reg.event).plan

      expect(plan.map(&:action)).to eq([ :noop ])
      expect(plan.first.reason).to eq(described_class::ACTIVE_ATTENDED)
      expect(plan.first).not_to be_actionable
    end

    it "plans nothing when there is no owned facilitator affiliation" do
      reg = training_registration(status: "no_show")

      plan = described_class.new(person: person, organization: organization, event: reg.event).plan

      expect(plan).to be_empty
    end
  end

  describe "a non-training event" do
    it "deletes only the facilitator affiliation auto-created off that event" do
      event = create(:event, :ended, facilitator_training: false)
      reg = create(:event_registration, registrant: person, event: event, status: "attended")
      create(:event_registration_organization, event_registration: reg, organization: organization)
      off_this_event = owned_facilitator(registration: reg)
      hand_created = create(:affiliation, person: person, organization: organization,
                            title: "Facilitator", start_date: 2.years.ago.to_date)

      reconcile(reg)

      expect(Affiliation.exists?(off_this_event.id)).to be(false)
      expect(hand_created.reload).to be_active
    end
  end
end
