require "rails_helper"

RSpec.describe Faq do
  # let(:faq) { build(:faq) } # Keep if needed

  describe "associations" do
    # Add association tests if any
  end

  describe "validations" do
    subject { build(:faq) }
    it { should validate_presence_of(:question) }
    it { should validate_presence_of(:answer) }
  end

  describe "scopes" do
    describe ".active" do
      let!(:active_faq) { create(:faq, inactive: false) }
      let!(:inactive_faq) { create(:faq, inactive: true) }

      it "returns only active FAQs" do
        expect(Faq.active).to contain_exactly(active_faq)
        expect(Faq.active).not_to include(inactive_faq)
      end
    end

    describe ".by_order" do
      let!(:second_faq) { create(:faq, ordering: 1) }
      let!(:third_faq) { create(:faq, ordering: 2) }
      let!(:first_faq) { create(:faq, ordering: 0) }

      it "returns FAQs ordered by ordering ascending" do
        expect(Faq.reorder(nil).by_order).to eq([first_faq, second_faq, third_faq])
      end
    end
  end

  describe ".search_by_params" do
    let!(:active_faq)   { create(:faq, question: "How to reset password?", inactive: false) }
    let!(:inactive_faq) { create(:faq, question: "Admin only FAQ", inactive: true) }

    it "returns all when no params" do
      expect(Faq.search_by_params({})).to match_array([active_faq, inactive_faq])
    end

    it "filters by query (case-insensitive substring)" do
      results = Faq.search_by_params({ query: "reset" })
      expect(results).to include(active_faq)
      expect(results).not_to include(inactive_faq)
    end

    it "filters by inactive param when true" do
      results = Faq.search_by_params({ inactive: true })
      expect(results).to contain_exactly(inactive_faq)
    end

    it "filters by inactive param when false" do
      results = Faq.search_by_params({ inactive: false })
      expect(results).to contain_exactly(active_faq)
    end

    it "chains query and inactive filters" do
      results = Faq.search_by_params({ query: "Admin", inactive: true })
      expect(results).to contain_exactly(inactive_faq)
    end
  end
end


