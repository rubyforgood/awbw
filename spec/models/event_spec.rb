require "rails_helper"

RSpec.describe Event, type: :model do
  describe "validations" do
    it { should validate_presence_of(:title) }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }
    it { should validate_numericality_of(:cost_cents).is_greater_than_or_equal_to(0).allow_nil }
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
end
