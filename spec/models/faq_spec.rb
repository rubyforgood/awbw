# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Faq) do
  # let(:faq) { build(:faq) } # Keep if needed

  describe "validations" do
    subject { build(:faq) }

    it { is_expected.to(validate_presence_of(:question)) }
    it { is_expected.to(validate_presence_of(:answer)) }
  end

  describe "scopes" do
    let!(:active_faq) { create(:faq, inactive: false, ordering: 1) }
    let!(:inactive_faq) { create(:faq, inactive: true, ordering: 2) }
    let!(:active_faq_2) { create(:faq, inactive: false, ordering: 0) }

    it ".active returns only active FAQs" do
      expect(described_class.active).to(contain_exactly(active_faq, active_faq_2))
      expect(described_class.active).not_to(include(inactive_faq))
    end

    it ".by_order returns FAQs ordered by ordering descending" do
      # NOTE: Default scope might interfere; consider unscoped if necessary
      expect(described_class.reorder(nil).by_order).to(eq([inactive_faq, active_faq, active_faq_2]))
    end
  end
end
