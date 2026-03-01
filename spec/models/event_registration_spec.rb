require "rails_helper"

RSpec.describe EventRegistration, type: :model do
  subject { create(:event_registration) }

  describe "associations" do
    it { should belong_to(:event).required }
    it { should belong_to(:registrant).required }
    it { should have_many(:comments).dependent(:destroy) }
    it { should have_many(:event_registration_organizations).dependent(:destroy) }
    it { should have_many(:organizations).through(:event_registration_organizations) }
  end

  describe "#active?" do
    it "returns true for registered status" do
      reg = create(:event_registration, status: "registered")
      expect(reg).to be_active
    end

    it "returns true for attended status" do
      reg = create(:event_registration, status: "attended")
      expect(reg).to be_active
    end

    it "returns true for incomplete_attendance status" do
      reg = create(:event_registration, status: "incomplete_attendance")
      expect(reg).to be_active
    end

    it "returns false for cancelled status" do
      reg = create(:event_registration, status: "cancelled")
      expect(reg).not_to be_active
    end

    it "returns false for no_show status" do
      reg = create(:event_registration, status: "no_show")
      expect(reg).not_to be_active
    end
  end

  describe ".active" do
    it "returns only registrations with active statuses" do
      active_reg = create(:event_registration, status: "registered")
      cancelled_reg = create(:event_registration, status: "cancelled")
      no_show_reg = create(:event_registration, status: "no_show")

      results = EventRegistration.active
      expect(results).to include(active_reg)
      expect(results).not_to include(cancelled_reg, no_show_reg)
    end
  end

  describe "#scholarship_recipient?" do
    it "returns true when scholarship_recipient is true" do
      reg = create(:event_registration, :scholarship)
      expect(reg).to be_scholarship_recipient
    end

    it "returns false when scholarship_recipient is false" do
      reg = create(:event_registration)
      expect(reg).not_to be_scholarship_recipient
    end
  end

  describe "#joinable?" do
    let(:event) { create(:event, cost_cents: 1099) }
    let(:user) { create(:user, :with_person) }

    it "returns true for active, paid registration" do
      payment = create(:payment, :succeeded, payer: user.person, amount_cents: 1099)
      reg = create(:event_registration, event: event, registrant: user.person, payment: payment)
      expect(reg).to be_joinable
    end

    it "returns false when not active" do
      payment = create(:payment, :succeeded, payer: user.person, amount_cents: 1099)
      reg = create(:event_registration, event: event, registrant: user.person, status: "cancelled", payment: payment)
      expect(reg).not_to be_joinable
    end

    it "returns false when not paid" do
      reg = create(:event_registration, event: event, registrant: user.person)
      expect(reg).not_to be_joinable
    end

    it "returns true for scholarship recipient with tasks completed" do
      reg = create(:event_registration, :scholarship, event: event, registrant: user.person)
      expect(reg).to be_joinable
    end

    it "returns false for scholarship recipient with tasks not completed" do
      reg = create(:event_registration, event: event, registrant: user.person, scholarship_recipient: true, scholarship_tasks_completed: false)
      expect(reg).not_to be_joinable
    end

    it "returns true for free event with active registration" do
      free_event = create(:event, cost_cents: 0)
      reg = create(:event_registration, event: free_event, registrant: user.person)
      expect(reg).to be_joinable
    end
  end

  describe "#paid_in_full?" do
    let(:event) { create(:event, cost_cents: 1000) }
    let(:user) { create(:user, :with_person) }

    it "returns true when event is free" do
      free_event = create(:event, cost_cents: 0)
      reg = create(:event_registration, event: free_event, registrant: user.person)
      expect(reg).to be_paid_in_full
    end

    it "returns true when registrant is a scholarship recipient" do
      reg = create(:event_registration, :scholarship, event: event, registrant: user.person)
      expect(reg).to be_paid_in_full
    end

    it "returns true when payment covers cost" do
      payment = create(:payment, :succeeded, payer: user.person, amount_cents: 1000)
      reg = create(:event_registration, event: event, registrant: user.person, payment: payment)
      expect(reg).to be_paid_in_full
    end

    it "returns false when payment is insufficient" do
      payment = create(:payment, :succeeded, payer: user.person, amount_cents: 500)
      reg = create(:event_registration, event: event, registrant: user.person, payment: payment)
      expect(reg).not_to be_paid_in_full
    end

    it "returns false when payment is not succeeded" do
      payment = create(:payment, :pending, payer: user.person, amount_cents: 1000)
      reg = create(:event_registration, event: event, registrant: user.person, payment: payment)
      expect(reg).not_to be_paid_in_full
    end

    it "returns false when no payment exists" do
      reg = create(:event_registration, event: event, registrant: user.person)
      expect(reg).not_to be_paid_in_full
    end
  end

  describe '.search_by_params' do
    let(:person_alice) { create(:person, first_name: 'Alice', last_name: 'Smith') }
    let(:person_bob) { create(:person, first_name: 'Bob', last_name: 'Jones') }
    let(:event_art) { create(:event, title: 'Art Workshop') }
    let(:event_music) { create(:event, title: 'Music Session') }

    let!(:reg_alice_art) { create(:event_registration, registrant: person_alice, event: event_art) }
    let!(:reg_bob_music) { create(:event_registration, registrant: person_bob, event: event_music) }

    it 'returns all when no params' do
      results = EventRegistration.search_by_params({})
      expect(results).to include(reg_alice_art, reg_bob_music)
    end

    it 'filters by registrant_id' do
      results = EventRegistration.search_by_params(registrant_id: person_alice.id)
      expect(results).to include(reg_alice_art)
      expect(results).not_to include(reg_bob_music)
    end

    it 'filters by event_id' do
      results = EventRegistration.search_by_params(event_id: event_music.id)
      expect(results).to include(reg_bob_music)
      expect(results).not_to include(reg_alice_art)
    end

    it 'chains registrant_id and event_id filters' do
      results = EventRegistration.search_by_params(registrant_id: person_alice.id, event_id: event_art.id)
      expect(results).to include(reg_alice_art)
      expect(results).not_to include(reg_bob_music)
    end
  end

  describe "cancellation emails" do
    it "sends cancellation emails when status changes to cancelled" do
      reg = create(:event_registration, status: "registered")

      expect(NotificationServices::CreateNotification).to receive(:call).with(
        hash_including(kind: "event_registration_cancelled", recipient_role: :person)
      )
      expect(NotificationServices::CreateNotification).to receive(:call).with(
        hash_including(kind: "event_registration_cancelled_fyi", recipient_role: :admin)
      )

      reg.update!(status: "cancelled")
    end

    it "does not send emails when status changes to something other than cancelled" do
      reg = create(:event_registration, status: "registered")

      expect(NotificationServices::CreateNotification).not_to receive(:call)

      reg.update!(status: "attended")
    end

    it "does not send emails when a non-status attribute changes" do
      reg = create(:event_registration, status: "cancelled")

      expect(NotificationServices::CreateNotification).not_to receive(:call)

      reg.update!(scholarship_recipient: true)
    end
  end

  describe "snapshot_registrant_organizations" do
    it "copies active affiliations to the registration on create" do
      org = create(:organization)
      person = create(:person)
      create(:affiliation, person: person, organization: org)

      reg = create(:event_registration, registrant: person)
      expect(reg.organizations).to include(org)
    end

    it "copies multiple active affiliations" do
      org1 = create(:organization)
      org2 = create(:organization)
      person = create(:person)
      create(:affiliation, person: person, organization: org1)
      create(:affiliation, person: person, organization: org2)

      reg = create(:event_registration, registrant: person)
      expect(reg.organizations).to contain_exactly(org1, org2)
    end

    it "skips inactive affiliations" do
      org = create(:organization)
      person = create(:person)
      create(:affiliation, person: person, organization: org, inactive: true)

      reg = create(:event_registration, registrant: person)
      expect(reg.organizations).to be_empty
    end

    it "skips affiliations with past end dates" do
      org = create(:organization)
      person = create(:person)
      create(:affiliation, person: person, organization: org, end_date: 1.day.ago)

      reg = create(:event_registration, registrant: person)
      expect(reg.organizations).to be_empty
    end

    it "creates no records when registrant has no affiliations" do
      person = create(:person)
      reg = create(:event_registration, registrant: person)
      expect(reg.organizations).to be_empty
    end
  end

  describe "slug" do
    it "generates a slug on create" do
      registration = create(:event_registration)
      expect(registration.slug).to be_present
      expect(registration.slug.length).to eq(22)
    end

    it "does not change slug on update" do
      registration = create(:event_registration)
      original_slug = registration.slug
      registration.update!(status: "attended")
      expect(registration.reload.slug).to eq(original_slug)
    end

    it "generates unique slugs" do
      slugs = 10.times.map { create(:event_registration).slug }
      expect(slugs.uniq.size).to eq(10)
    end
  end
end
