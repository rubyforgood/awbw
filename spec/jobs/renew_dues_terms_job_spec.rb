require "rails_helper"

RSpec.describe RenewDuesTermsJob, type: :job do
  def term_ending(date, membership: create(:dues_membership))
    create(:dues_registration,
      dues_membership: membership,
      start_date: date - 1.year + 1.day,
      end_date: date)
  end

  describe "#perform" do
    it "creates the next term for one expiring inside the window" do
      term = term_ending(Date.current + 10.days)

      expect { described_class.new.perform }.to change(DuesRegistration, :count).by(1)

      renewal = term.dues_membership.dues_registrations.order(:start_date).last
      expect(renewal.start_date).to eq(term.end_date + 1.day)
      expect(renewal.end_date).to eq(term.end_date + 1.year)
      expect(renewal.cost_cents).to eq(Dues::ANNUAL_COST_CENTS)
    end

    it "creates one for a term expiring on the window's last day" do
      term_ending(Date.current + Dues::RENEWAL_WINDOW_DAYS)

      expect { described_class.new.perform }.to change(DuesRegistration, :count).by(1)
    end

    it "leaves a term expiring beyond the window alone" do
      term_ending(Date.current + Dues::RENEWAL_WINDOW_DAYS + 1)

      expect { described_class.new.perform }.not_to change(DuesRegistration, :count)
    end

    it "skips a cancelled membership" do
      term_ending(Date.current + 10.days, membership: create(:dues_membership, :cancelled))

      expect { described_class.new.perform }.not_to change(DuesRegistration, :count)
    end

    it "carries the membership's own rate onto the renewal" do
      membership = create(:dues_membership, rate_cents: 1_500)
      term_ending(Date.current + 10.days, membership: membership)

      described_class.new.perform

      expect(membership.dues_registrations.order(:start_date).last.cost_cents).to eq(1_500)
    end

    it "charges the standard rate after a comped year" do
      membership = create(:dues_membership)
      create(:dues_registration, :comped,
        dues_membership: membership,
        start_date: Date.current - 1.year + 10.days,
        end_date: Date.current + 10.days)

      described_class.new.perform

      expect(membership.dues_registrations.order(:start_date).last.cost_cents)
        .to eq(Dues::ANNUAL_COST_CENTS)
    end

    it "renews an unpaid term, since renewal doesn't depend on payment" do
      term_ending(Date.current + 10.days)

      expect { described_class.new.perform }.to change(DuesRegistration, :count).by(1)
    end

    it "creates nothing on a second run" do
      term_ending(Date.current + 10.days)
      described_class.new.perform

      expect { described_class.new.perform }.not_to change(DuesRegistration, :count)
    end

    it "handles several memberships in one pass" do
      3.times { term_ending(Date.current + 5.days) }

      expect { described_class.new.perform }.to change(DuesRegistration, :count).by(3)
    end
  end
end
