require "rails_helper"

RSpec.describe DuesRegistration, type: :model do
  describe "validations" do
    it "requires both dates" do
      term = build(:dues_registration, start_date: nil, end_date: nil)
      expect(term).not_to be_valid
      expect(term.errors[:start_date]).to be_present
      expect(term.errors[:end_date]).to be_present
    end

    it "rejects an end date before the start date" do
      term = build(:dues_registration, start_date: Date.current, end_date: Date.current - 1)
      expect(term).not_to be_valid
      expect(term.errors[:end_date]).to be_present
    end

    it "allows a single-day term" do
      expect(build(:dues_registration, start_date: Date.current, end_date: Date.current)).to be_valid
    end

    it "rejects a negative cost" do
      term = build(:dues_registration, cost_cents: -1)
      expect(term).not_to be_valid
      expect(term.errors[:cost_cents]).to be_present
    end

    it "allows a zero cost, meaning a comped year" do
      expect(build(:dues_registration, :comped)).to be_valid
    end
  end

  describe "overlap" do
    let(:person) { create(:person) }
    let(:membership) { create(:dues_membership, person: person) }
    let!(:existing) do
      create(:dues_registration,
        dues_membership: membership,
        start_date: Date.new(2026, 10, 14),
        end_date: Date.new(2027, 10, 13))
    end

    it "rejects a term overlapping an existing one" do
      term = build(:dues_registration,
        dues_membership: membership,
        start_date: Date.new(2027, 1, 1),
        end_date: Date.new(2027, 12, 31))

      expect(term).not_to be_valid
      expect(term.errors[:base].join).to match(/overlapping/)
    end

    it "rejects a term that merely shares the last day" do
      term = build(:dues_registration,
        dues_membership: membership,
        start_date: Date.new(2027, 10, 13),
        end_date: Date.new(2028, 10, 12))

      expect(term).not_to be_valid
    end

    it "accepts a term starting the day after the previous one ends" do
      term = build(:dues_registration,
        dues_membership: membership,
        start_date: Date.new(2027, 10, 14),
        end_date: Date.new(2028, 10, 13))

      expect(term).to be_valid
    end

    it "rejects an overlap that sits under a different membership for the same person" do
      existing.dues_membership.update!(cancelled_at: Time.current)
      rejoined = create(:dues_membership, person: person)

      term = build(:dues_registration,
        dues_membership: rejoined,
        start_date: Date.new(2027, 1, 1),
        end_date: Date.new(2027, 12, 31))

      expect(term).not_to be_valid
      expect(term.errors[:base].join).to match(/overlapping/)
    end

    it "allows another person to hold the same dates" do
      term = build(:dues_registration,
        dues_membership: create(:dues_membership),
        start_date: existing.start_date,
        end_date: existing.end_date)

      expect(term).to be_valid
    end

    it "does not treat a persisted term as overlapping itself" do
      existing.cost_cents = 3_000
      expect(existing).to be_valid
    end
  end

  describe "the payment interface from Registerable" do
    let(:term) { create(:dues_registration, cost_cents: 2_500) }

    it "treats a comped year as paid with nothing allocated" do
      expect(create(:dues_registration, :comped)).to be_paid_in_full
    end

    it "is unpaid until allocations cover the cost" do
      expect(term).not_to be_paid_in_full
      expect(term.remaining_cost).to eq(2_500)
    end

    it "is paid once a payment covers the cost" do
      create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: term, amount: 2_500)

      expect(term.reload).to be_paid_in_full
      expect(term.remaining_cost).to eq(0)
      expect(term.payments_sum).to eq(2_500)
    end

    it "is partially paid when a payment covers only part of the cost" do
      create(:allocation, source: create(:payment, amount_cents: 1_000), allocatable: term, amount: 1_000)

      expect(term.reload).to be_partially_paid
      expect(term.remaining_cost).to eq(1_500)
    end

    it "counts a discount towards the cost but not towards payments" do
      create(:allocation, source: create(:discount, amount_cents: 2_500), allocatable: term, amount: 2_500)

      expect(term.reload).to be_paid_in_full
      expect(term).to be_discounted
      expect(term.discount_sum).to eq(2_500)
      expect(term.payments_sum).to eq(0)
      expect(term).not_to be_payment_received
    end

    it "does not respond to the certificate interface" do
      expect(term).not_to respond_to(:certificate_available?)
    end
  end

  describe "#cost_cents" do
    it "cannot be lowered below what has already been allocated" do
      term = create(:dues_registration, cost_cents: 2_500)
      create(:allocation, source: create(:payment, amount_cents: 2_500), allocatable: term, amount: 2_500)

      term.reload.cost_cents = 1_000
      expect(term).not_to be_valid
      expect(term.errors[:cost_cents].join).to match(/already allocated/)
    end
  end

  describe "#person" do
    it "comes through the membership" do
      membership = create(:dues_membership)
      expect(create(:dues_registration, dues_membership: membership).person).to eq(membership.person)
    end
  end
end
