require "rails_helper"

RSpec.describe EventRegistration, type: :model do
  subject { create(:event_registration) }

  describe "associations" do
    it { should belong_to(:event).required }
    it { should belong_to(:registrant).required }
    it { should have_many(:comments).dependent(:destroy) }
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

  describe "#scholarship?" do
    it "returns true when registration has a scholarship payment" do
      reg = create(:event_registration)
      create(:payment, :scholarship, :succeeded, payable: reg, payer: reg.registrant.user, amount_cents: 1099)
      expect(reg).to be_scholarship
    end

    it "returns false when registration has only stripe payments" do
      reg = create(:event_registration)
      create(:payment, :succeeded, payable: reg, payer: reg.registrant.user, amount_cents: 1099)
      expect(reg).not_to be_scholarship
    end

    it "returns false when registration has no payments" do
      reg = create(:event_registration)
      expect(reg).not_to be_scholarship
    end
  end

  describe "#scholarship_tasks_met?" do
    it "returns true when no scholarship payment exists" do
      reg = create(:event_registration)
      expect(reg.scholarship_tasks_met?).to be true
    end

    it "returns false when scholarship exists but tasks not completed" do
      reg = create(:event_registration, scholarship_tasks_completed: false)
      create(:payment, :scholarship, :succeeded, payable: reg, payer: reg.registrant.user, amount_cents: 1099)
      expect(reg.scholarship_tasks_met?).to be false
    end

    it "returns true when scholarship exists and tasks completed" do
      reg = create(:event_registration, scholarship_tasks_completed: true)
      create(:payment, :scholarship, :succeeded, payable: reg, payer: reg.registrant.user, amount_cents: 1099)
      expect(reg.scholarship_tasks_met?).to be true
    end
  end

  describe "#joinable?" do
    let(:event) { create(:event, cost_cents: 1099) }
    let(:user) { create(:user, :with_person) }

    it "returns true for active, paid, non-scholarship registration" do
      reg = create(:event_registration, event: event, registrant: user.person)
      create(:payment, :succeeded, payable: reg, payer: user, amount_cents: 1099)
      expect(reg).to be_joinable
    end

    it "returns false when not active" do
      reg = create(:event_registration, event: event, registrant: user.person, status: "cancelled")
      create(:payment, :succeeded, payable: reg, payer: user, amount_cents: 1099)
      expect(reg).not_to be_joinable
    end

    it "returns false when not paid" do
      reg = create(:event_registration, event: event, registrant: user.person)
      expect(reg).not_to be_joinable
    end

    it "returns false for scholarship with tasks not completed" do
      reg = create(:event_registration, event: event, registrant: user.person, scholarship_tasks_completed: false)
      create(:payment, :scholarship, :succeeded, payable: reg, payer: user, amount_cents: 1099)
      expect(reg).not_to be_joinable
    end

    it "returns true for scholarship with tasks completed" do
      reg = create(:event_registration, event: event, registrant: user.person, scholarship_tasks_completed: true)
      create(:payment, :scholarship, :succeeded, payable: reg, payer: user, amount_cents: 1099)
      expect(reg).to be_joinable
    end

    it "returns true for free event with active registration" do
      free_event = create(:event, cost_cents: 0)
      reg = create(:event_registration, event: free_event, registrant: user.person)
      expect(reg).to be_joinable
    end

    it "returns true for partial scholarship + partial payment covering full cost" do
      reg = create(:event_registration, event: event, registrant: user.person, scholarship_tasks_completed: true)
      create(:payment, :scholarship, :succeeded, payable: reg, payer: user, amount_cents: 500)
      create(:payment, :succeeded, payable: reg, payer: user, amount_cents: 599)
      expect(reg).to be_joinable
    end

    it "returns false for partial scholarship + partial payment not covering full cost" do
      reg = create(:event_registration, event: event, registrant: user.person, scholarship_tasks_completed: true)
      create(:payment, :scholarship, :succeeded, payable: reg, payer: user, amount_cents: 500)
      create(:payment, :succeeded, payable: reg, payer: user, amount_cents: 100)
      expect(reg).not_to be_joinable
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

    it "returns true when payments cover cost" do
      reg = create(:event_registration, event: event, registrant: user.person)
      create(:payment, :succeeded, payable: reg, payer: user, amount_cents: 1000)
      expect(reg).to be_paid_in_full
    end

    it "returns false when payments are insufficient" do
      reg = create(:event_registration, event: event, registrant: user.person)
      create(:payment, :succeeded, payable: reg, payer: user, amount_cents: 500)
      expect(reg).not_to be_paid_in_full
    end

    it "returns correct result when payments are preloaded" do
      reg = create(:event_registration, event: event, registrant: user.person)
      create(:payment, :succeeded, payable: reg, payer: user, amount_cents: 1000)

      preloaded = EventRegistration.includes(:payments).find(reg.id)
      expect(preloaded.payments).to be_loaded
      expect(preloaded).to be_paid_in_full
    end

    it "returns correct result when preloaded payments are insufficient" do
      reg = create(:event_registration, event: event, registrant: user.person)
      create(:payment, :succeeded, payable: reg, payer: user, amount_cents: 500)

      preloaded = EventRegistration.includes(:payments).find(reg.id)
      expect(preloaded.payments).to be_loaded
      expect(preloaded).not_to be_paid_in_full
    end

    it "ignores non-succeeded payments when preloaded" do
      reg = create(:event_registration, event: event, registrant: user.person)
      create(:payment, payable: reg, payer: user, amount_cents: 1000, status: "pending")

      preloaded = EventRegistration.includes(:payments).find(reg.id)
      expect(preloaded.payments).to be_loaded
      expect(preloaded).not_to be_paid_in_full
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
end
