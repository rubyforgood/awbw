require "rails_helper"

RSpec.describe DuesSubscription, type: :model do
  describe "validations" do
    it "allows a nil rate_cents, meaning the standard rate" do
      expect(build(:dues_subscription, rate_cents: nil)).to be_valid
    end

    it "allows a zero rate_cents, meaning a comped member" do
      expect(build(:dues_subscription, rate_cents: 0)).to be_valid
    end

    it "rejects a negative rate_cents" do
      subscription = build(:dues_subscription, rate_cents: -1)
      expect(subscription).not_to be_valid
      expect(subscription.errors[:rate_cents]).to be_present
    end

    it "rejects a second uncancelled subscription for the same person" do
      person = create(:person)
      create(:dues_subscription, person: person)

      second = build(:dues_subscription, person: person)
      expect(second).not_to be_valid
      expect(second.errors[:base].join).to match(/already has a dues subscription/)
    end

    it "allows a new subscription once the previous one is cancelled" do
      person = create(:person)
      create(:dues_subscription, :cancelled, person: person)

      expect(build(:dues_subscription, person: person)).to be_valid
    end

    it "allows two people to each have an uncancelled subscription" do
      create(:dues_subscription)
      expect(build(:dues_subscription)).to be_valid
    end

    it "does not treat a persisted subscription as its own duplicate" do
      subscription = create(:dues_subscription)
      subscription.rate_cents = 1_500
      expect(subscription).to be_valid
    end
  end

  describe "#cancelled?" do
    it "is false while cancelled_at is blank" do
      expect(build(:dues_subscription)).not_to be_cancelled
    end

    it "is true once cancelled_at is stamped" do
      expect(build(:dues_subscription, :cancelled)).to be_cancelled
    end
  end

  describe "scopes" do
    let!(:open_subscription) { create(:dues_subscription) }
    let!(:cancelled_subscription) { create(:dues_subscription, :cancelled) }

    it "separates cancelled from uncancelled" do
      expect(described_class.not_cancelled).to contain_exactly(open_subscription)
      expect(described_class.cancelled).to contain_exactly(cancelled_subscription)
    end
  end

  describe "associations" do
    it "destroys its terms with it" do
      subscription = create(:dues_subscription)
      create(:dues_registration, dues_subscription: subscription)

      expect { subscription.destroy }.to change(DuesRegistration, :count).by(-1)
    end

    it "is reachable from the person, along with their terms" do
      subscription = create(:dues_subscription)
      term = create(:dues_registration, dues_subscription: subscription)

      expect(subscription.person.dues_subscriptions).to contain_exactly(subscription)
      expect(subscription.person.dues_registrations).to contain_exactly(term)
    end
  end
end
