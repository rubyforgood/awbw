require "rails_helper"

RSpec.describe Event, type: :model do
  describe "validations" do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }
    it { should validate_numericality_of(:cost_cents).is_greater_than_or_equal_to(0).allow_nil }
  end

  describe "destroying with form submissions" do
    it "is blocked and keeps the submission when the event has one" do
      event = create(:event)
      create(:form_submission, :with_event, event: event)

      expect(event.destroy).to be(false)
      expect(event.errors[:base]).to be_present
      expect(Event.exists?(event.id)).to be(true)
    end

    it "is allowed when the event has no submissions" do
      event = create(:event)

      expect(event.destroy).to be_truthy
      expect(Event.exists?(event.id)).to be(false)
    end
  end

  describe "staff uniqueness on update" do
    it "rejects two staff rows for the same person added in one update" do
      event = create(:event)
      person = create(:person)
      event.update(event_staffs_attributes: {
        "0" => { person_id: person.id, title: "Lead" },
        "1" => { person_id: person.id, title: "Assistant" }
      })
      expect(event).to be_invalid
      expect(event.errors[:base]).to include("A person can only be added to the staff once.")
      expect(event.event_staffs.reload).to be_empty
    end

    it "allows distinct people in one update" do
      event = create(:event)
      expect(event.update(event_staffs_attributes: {
        "0" => { person_id: create(:person).id, title: "Lead" },
        "1" => { person_id: create(:person).id, title: "Assistant" }
      })).to be(true)
      expect(event.event_staffs.reload.count).to eq(2)
    end
  end

  describe "#date_title" do
    it "labels the event by date and title, without the time or parens" do
      event = build(:event, title: "Youth Creativity Day", start_date: Time.zone.local(2026, 9, 14, 14, 9))
      expect(event.date_title).to eq("2026-09-14 — Youth Creativity Day")
    end
  end

  describe ".in_year" do
    it "matches events by the calendar year of their start date" do
      in_year = create(:event, start_date: Time.zone.parse("2025-06-01 09:00"))
      other_year = create(:event, start_date: Time.zone.parse("2024-06-01 09:00"))
      expect(Event.in_year(2025)).to include(in_year)
      expect(Event.in_year(2025)).not_to include(other_year)
    end

    it "includes a same-day start time on Dec 31 (not just midnight)" do
      nye = create(:event, start_date: Time.zone.parse("2025-12-31 09:00"))
      expect(Event.in_year(2025)).to include(nye)
    end
  end

  describe ".live and .on_demand" do
    it "partitions events by delivery format" do
      live = create(:event, on_demand: false)
      on_demand = create(:event, on_demand: true)
      expect(Event.live).to include(live)
      expect(Event.live).not_to include(on_demand)
      expect(Event.on_demand).to include(on_demand)
      expect(Event.on_demand).not_to include(live)
    end
  end

  describe ".upcoming" do
    it "includes an event starting today" do
      # start_date is a date column, so comparing against a time-of-day would
      # drop today's events at midnight.
      today = create(:event, start_date: Date.current)
      expect(Event.upcoming).to include(today)
    end

    it "excludes an event that already started" do
      past = create(:event, start_date: 1.day.ago)
      expect(Event.upcoming).not_to include(past)
    end
  end

  describe "#ended?" do
    it "returns true when end_date is in the past" do
      event = build(:event, end_date: 1.day.ago)
      expect(event.ended?).to be true
    end

    it "returns false when end_date is in the future" do
      event = build(:event, end_date: 1.day.from_now)
      expect(event.ended?).to be false
    end
  end

  describe "#shown_as_card?" do
    it "is true for a published event that has not ended" do
      event = build(:event, :published, end_date: 1.day.from_now)
      expect(event.shown_as_card?).to be true
    end

    it "is true for a published event that ended within the last month" do
      event = build(:event, :published, end_date: 1.week.ago)
      expect(event.shown_as_card?).to be true
    end

    it "is false for an unpublished event" do
      event = build(:event, :unpublished, end_date: 1.day.from_now)
      expect(event.shown_as_card?).to be false
    end

    it "is false for a published event that ended more than a month ago" do
      event = build(:event, :published, end_date: (1.month + 1.day).ago)
      expect(event.shown_as_card?).to be false
    end
  end

  describe "#videoconference_window_open?" do
    it "returns false more than 30 minutes before the start" do
      event = build(:event, start_date: 31.minutes.from_now, end_date: 2.hours.from_now)
      expect(event.videoconference_window_open?).to be false
    end

    it "returns true within 30 minutes before the start" do
      event = build(:event, start_date: 29.minutes.from_now, end_date: 2.hours.from_now)
      expect(event.videoconference_window_open?).to be true
    end

    it "returns true while the event is in progress" do
      event = build(:event, start_date: 1.hour.ago, end_date: 1.hour.from_now)
      expect(event.videoconference_window_open?).to be true
    end

    it "returns true within 30 minutes after the end" do
      event = build(:event, start_date: 2.hours.ago, end_date: 29.minutes.ago)
      expect(event.videoconference_window_open?).to be true
    end

    it "returns false more than 30 minutes after the end" do
      event = build(:event, start_date: 2.hours.ago, end_date: 31.minutes.ago)
      expect(event.videoconference_window_open?).to be false
    end
  end

  describe "#videoconference_details_visible?" do
    it "is visible when no videoconference callout has been materialized (nothing to gate on)" do
      event = create(:event, start_date: 8.days.from_now, end_date: 8.days.from_now + 2.hours)
      expect(event.videoconference_details_visible?).to be true
    end

    it "is gated while the materialized callout's drip date is still in the future" do
      event = create(:event, start_date: 6.days.from_now, end_date: 6.days.from_now + 2.hours)
      create(:registration_ticket_callout, event:, builtin_key: "videoconference",
        display_from: 2.days.from_now)

      expect(event.videoconference_details_visible?).to be false
    end

    it "is visible once the materialized callout's drip date has passed" do
      event = create(:event, start_date: 6.days.from_now, end_date: 6.days.from_now + 2.hours)
      create(:registration_ticket_callout, event:, builtin_key: "videoconference",
        display_from: 1.day.ago)

      expect(event.videoconference_details_visible?).to be true
    end

    it "is visible immediately when the callout's drip date has been cleared" do
      event = create(:event, start_date: 6.days.from_now, end_date: 6.days.from_now + 2.hours)
      create(:registration_ticket_callout, event:, builtin_key: "videoconference", display_from: nil)

      expect(event.videoconference_details_visible?).to be true
    end
  end

  describe "#registerable?" do
    it "returns true when registration_close_date is in the future" do
      event = build(:event, published: true, registration_close_date: 5.days.from_now)
      expect(event.registerable?).to be true
    end

    it "returns true when registration_close_date is nil" do
      event = build(:event, published: true, registration_close_date: nil)
      expect(event.registerable?).to be true
    end

    it "returns false when registration_close_date is in the past" do
      event = build(:event, published: true, registration_close_date: 1.day.ago)
      expect(event.registerable?).to be false
    end

    it "returns true when unpublished but registration_close_date is in the future" do
      event = build(:event, published: false, registration_close_date: 5.days.from_now)
      expect(event.registerable?).to be true
    end

    it "returns true when unpublished and registration_close_date is nil" do
      event = build(:event, published: false, registration_close_date: nil)
      expect(event.registerable?).to be true
    end

    it "returns false when event has ended even with future registration_close_date" do
      event = build(:event, end_date: 1.day.ago, registration_close_date: 5.days.from_now)
      expect(event.registerable?).to be false
    end
  end

  describe "#active_registration_for" do
    let(:event) { create(:event) }
    let(:person) { create(:person) }

    it "returns nil when person is nil" do
      expect(event.active_registration_for(nil)).to be_nil
    end

    it "returns nil when person has no registration" do
      expect(event.active_registration_for(person)).to be_nil
    end

    it "returns the registration when person has an active registration" do
      reg = create(:event_registration, event: event, registrant: person, status: "registered")
      expect(event.active_registration_for(person)).to eq(reg)
    end

    it "returns nil when person has a cancelled registration" do
      create(:event_registration, event: event, registrant: person, status: "cancelled")
      expect(event.active_registration_for(person)).to be_nil
    end
  end

  describe "#actively_registered?" do
    let(:event) { create(:event) }
    let(:person) { create(:person) }

    it "returns false when person is nil" do
      expect(event.actively_registered?(nil)).to be false
    end

    it "returns true when person has an active registration" do
      create(:event_registration, event: event, registrant: person, status: "registered")
      expect(event.actively_registered?(person)).to be true
    end

    it "returns false when person has a cancelled registration" do
      create(:event_registration, event: event, registrant: person, status: "cancelled")
      expect(event.actively_registered?(person)).to be false
    end

    it "returns false when person has no registration" do
      expect(event.actively_registered?(person)).to be false
    end
  end

  describe "cost as virtual attribute of cost_cents" do
    let(:event) { create(:event, cost_cents: 5431) }

    describe "#cost" do
      it "represents cost in dollar amount" do
        expect(event.cost).to eq(54.31)
      end
    end

    describe "#cost=" do
      it "converts float cost in dollars to cost_cents field" do
        event.cost = 10.99
        expect(event.cost_cents).to eq(1099)
      end

      it "converts string cost in dollars to cost_cents field" do
        event.cost = "10.99"
        expect(event.cost_cents).to eq(1099)
      end
    end
  end

  describe "#build_public_registration_form" do
    let!(:default_form) { create(:form, name: "Short Event Registration") }
    let!(:extended_form) { create(:form, name: "Extended Event Registration") }

    it "links the default registration form by default" do
      event = create(:event, public_registration_enabled: true)
      expect(event.event_forms.registration.exists?).to be true
      expect(event.registration_form).to eq(default_form)
    end

    it "links the extended registration form when title contains training" do
      event = create(:event, title: "Facilitator Training", public_registration_enabled: true)
      expect(event.event_forms.registration.exists?).to be true
      expect(event.registration_form).to eq(extended_form)
    end

    it "does not link a form when public_registration_enabled is false" do
      event = create(:event, public_registration_enabled: false)
      expect(event.event_forms.registration.exists?).to be false
    end

    it "links a form when toggled to true on update" do
      event = create(:event, public_registration_enabled: false)
      event.update!(public_registration_enabled: true)
      expect(event.event_forms.registration.exists?).to be true
      expect(event.registration_form).to eq(default_form)
    end

    it "does not duplicate the link if one already exists" do
      event = create(:event, public_registration_enabled: true)
      expect(event.event_forms.registration.count).to eq(1)

      event.update!(title: "Updated title")
      expect(event.event_forms.registration.count).to eq(1)
    end
  end

  describe "#registration_form" do
    it "returns the form linked with registration role" do
      form = create(:form, name: "My Registration")
      event = create(:event)
      create(:event_form, event: event, form: form, role: "registration")
      expect(event.registration_form).to eq(form)
    end

    it "returns nil when no registration form is linked" do
      event = create(:event)
      expect(event.registration_form).to be_nil
    end
  end

  describe "#registration_form_ids" do
    it "returns only the ids of forms linked with the registration role" do
      event = create(:event)
      registration_form = create(:form, name: "Registration")
      bulk_payment_form = create(:form, name: "Bulk payment")
      create(:event_form, event: event, form: registration_form, role: "registration")
      create(:event_form, event: event, form: bulk_payment_form, role: "bulk_payment")

      expect(event.registration_form_ids).to contain_exactly(registration_form.id)
    end

    it "returns an empty array when no registration form is linked" do
      event = create(:event)
      expect(event.registration_form_ids).to eq([])
    end
  end

  describe "#one_click_for_signed_in?" do
    it "is true when no registration form is linked" do
      event = create(:event)
      expect(event.one_click_for_signed_in?).to be true
    end

    it "is false when an empty registration form is linked" do
      form = create(:form, name: "Empty Registration")
      event = create(:event)
      create(:event_form, event: event, form: form, role: "registration")
      expect(event.one_click_for_signed_in?).to be false
    end

    it "is false when a registration form with fields is linked" do
      form = create(:form, :with_fields, name: "Real Registration")
      event = create(:event)
      create(:event_form, event: event, form: form, role: "registration")
      expect(event.one_click_for_signed_in?).to be false
    end

    it "is true when signed_in_one_click_enabled overrides a populated form" do
      form = create(:form, :with_fields, name: "Real Registration")
      event = create(:event, signed_in_one_click_enabled: true)
      create(:event_form, event: event, form: form, role: "registration")
      expect(event.one_click_for_signed_in?).to be true
    end
  end

  describe '.search_by_params' do
    let!(:art_event) { create(:event, title: 'Art Workshop Showcase', description: 'Annual art exhibition') }
    let!(:music_event) { create(:event, title: 'Music Therapy Session', description: 'Healing through music') }

    it 'returns all when no params' do
      results = Event.search_by_params({})
      expect(results).to include(art_event, music_event)
    end

    it 'filters by query matching title' do
      results = Event.search_by_params(query: 'Art Workshop')
      expect(results).to include(art_event)
      expect(results).not_to include(music_event)
    end

    it 'filters by query matching description' do
      results = Event.search_by_params(query: 'Healing')
      expect(results).to include(music_event)
      expect(results).not_to include(art_event)
    end

    it 'returns empty for non-matching query' do
      results = Event.search_by_params(query: 'nonexistent')
      expect(results).not_to include(art_event, music_event)
    end
  end

  describe "#ce_hours_cost (dollars)" do
    it "is nil when no cost is set" do
      expect(build(:event, ce_hours_cost_cents: nil).ce_hours_cost).to be_nil
    end

    it "reads the stored cost back in dollars" do
      expect(build(:event, ce_hours_cost_cents: 15_000).ce_hours_cost).to eq(150)
    end

    it "converts a dollar amount to cents on assignment" do
      expect(build(:event, ce_hours_cost: 150).ce_hours_cost_cents).to eq(15_000)
    end

    it "clears the cents when assigned blank" do
      expect(build(:event, ce_hours_cost: "").ce_hours_cost_cents).to be_nil
    end
  end

  describe "#ce_eligible?" do
    it "is true when the event offers a positive number of CE hours" do
      expect(build(:event, ce_hours_offered: 6)).to be_ce_eligible
    end

    it "is false when no CE hours are offered" do
      expect(build(:event, ce_hours_offered: nil)).not_to be_ce_eligible
    end

    it "is false when CE hours are zero" do
      expect(build(:event, ce_hours_offered: 0)).not_to be_ce_eligible
    end
  end

  describe "ce_payment_due_deadline date/time fields" do
    it "merges the date and time inputs into the datetime column on save" do
      event = create(:event,
                     ce_payment_due_deadline_date: "2026-07-22",
                     ce_payment_due_deadline_time: "09:00")
      deadline = event.reload.ce_payment_due_deadline
      expect(deadline.in_time_zone(Time.zone).strftime("%Y-%m-%d %H:%M")).to eq("2026-07-22 09:00")
    end

    it "exposes the stored deadline back through the virtual date/time readers" do
      event = create(:event, ce_payment_due_deadline: Time.zone.local(2026, 7, 22, 9, 0))
      expect(event.ce_payment_due_deadline_date).to eq("2026-07-22")
      expect(event.ce_payment_due_deadline_time).to eq("09:00")
    end

    it "leaves the deadline nil when both inputs are blank" do
      event = create(:event, ce_payment_due_deadline_date: "", ce_payment_due_deadline_time: "")
      expect(event.reload.ce_payment_due_deadline).to be_nil
    end
  end

  describe "#scholarship_eligible?" do
    it "is true when the event has a cost" do
      expect(build(:event, cost_cents: 1_000)).to be_scholarship_eligible
    end

    it "is true for a free event that offers a scholarship form" do
      event = create(:event, cost_cents: 0)
      create(:event_form, :scholarship, event: event)
      expect(event).to be_scholarship_eligible
    end

    it "is false for a free event with no scholarship form" do
      expect(create(:event, cost_cents: 0)).not_to be_scholarship_eligible
    end

    it "is false when the cost is unset and there is no scholarship form" do
      expect(create(:event, cost_cents: nil)).not_to be_scholarship_eligible
    end
  end

  describe "attendance sign-in window" do
    # A two-day training running 9:00am–4:00pm each day.
    let(:event) do
      create(:event,
        start_date: Time.zone.local(2026, 7, 23, 9, 0),
        end_date: Time.zone.local(2026, 7, 24, 16, 0),
        registration_close_date: Time.zone.local(2026, 7, 20, 9, 0))
    end

    describe "#event_dates" do
      it "lists each consecutive calendar day, inclusive" do
        expect(event.event_dates).to eq([ Date.new(2026, 7, 23), Date.new(2026, 7, 24) ])
      end

      it "is empty without a start date" do
        expect(build(:event, start_date: nil).event_dates).to eq([])
      end
    end

    describe "#daily_start_at / #daily_end_at" do
      it "applies the event's start/end time-of-day to each day" do
        day2 = Date.new(2026, 7, 24)
        expect(event.daily_start_at(day2)).to eq(Time.zone.local(2026, 7, 24, 9, 0))
        expect(event.daily_end_at(day2)).to eq(Time.zone.local(2026, 7, 24, 16, 0))
      end
    end

    describe "#attendance_sign_in_open?" do
      it "opens 30 minutes before a day's start" do
        expect(event.attendance_sign_in_open?(Time.zone.local(2026, 7, 23, 8, 30))).to be(true)
        expect(event.attendance_sign_in_open?(Time.zone.local(2026, 7, 23, 8, 29))).to be(false)
      end

      it "stays open through the day's end time" do
        expect(event.attendance_sign_in_open?(Time.zone.local(2026, 7, 23, 16, 0))).to be(true)
        expect(event.attendance_sign_in_open?(Time.zone.local(2026, 7, 23, 16, 1))).to be(false)
      end

      it "applies the same window to every event day" do
        expect(event.attendance_sign_in_open?(Time.zone.local(2026, 7, 24, 9, 0))).to be(true)
      end

      it "is closed overnight between event days" do
        expect(event.attendance_sign_in_open?(Time.zone.local(2026, 7, 23, 20, 0))).to be(false)
      end

      it "is closed on non-event days" do
        expect(event.attendance_sign_in_open?(Time.zone.local(2026, 7, 25, 9, 0))).to be(false)
      end
    end
  end
end
