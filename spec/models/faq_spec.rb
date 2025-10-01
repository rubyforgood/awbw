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
end

