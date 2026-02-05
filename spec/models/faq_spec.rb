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
    describe ".published" do
      let!(:published_faq) { create(:faq, published: false) }
      let!(:unpublished_faq) { create(:faq, published: true) }

      it "returns only published FAQs" do
        expect(Faq.published).to contain_exactly(published_faq)
        expect(Faq.published).not_to include(unpublished_faq)
      end
    end

    describe ".by_position" do
      let!(:second_faq) { create(:faq, position: 1) }
      let!(:third_faq) { create(:faq, position: 2) }
      let!(:first_faq) { create(:faq, position: 0) }

      it "returns FAQs ordered by position ascending" do
        expect(Faq.reorder(nil).by_position).to eq([ first_faq, second_faq, third_faq ])
      end
    end
  end

  describe ".search_by_params" do
    let!(:published_faq)   { create(:faq, question: "How to reset password?", published: false) }
    let!(:unpublished_faq) { create(:faq, question: "Admin only FAQ", published: true) }

    it "returns all when no params" do
      expect(Faq.search_by_params({})).to match_array([ published_faq, unpublished_faq ])
    end

    it "filters by query (case-insensitive substring)" do
      results = Faq.search_by_params({ query: "reset" })
      expect(results).to include(published_faq)
      expect(results).not_to include(unpublished_faq)
    end

    it "filters by unpublished param when true" do
      results = Faq.search_by_params({ published: true })
      expect(results).to contain_exactly(unpublished_faq)
    end

    it "filters by unpublished param when false" do
      results = Faq.search_by_params({ published: false })
      expect(results).to contain_exactly(published_faq)
    end

    it "chains query and unpublished filters" do
      results = Faq.search_by_params({ query: "Admin", published: true })
      expect(results).to contain_exactly(unpublished_faq)
    end
  end
end
