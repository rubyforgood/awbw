require "rails_helper"

RSpec.describe "FAQ", type: :system do
  include ActionView::RecordIdentifier

  let!(:active_faq) { create(:faq, inactive: false) }
  let!(:inactive_faq) { create(:faq, inactive: true) }

  context "Index" do
    context "as a regular user" do
      let(:user) { create(:user) }

      before do
        sign_in user
        visit faqs_path
      end

      it "shows only active FAQs" do
        expect(page).to have_content(active_faq.question)
        expect(page).not_to have_content(inactive_faq.question)
      end
    end

    context "as an admin" do
      let(:admin) { create(:user, :admin) }

      before do
        sign_in admin
        visit faqs_path
      end

      it "shows both active and inactive FAQs" do
        expect(page).to have_content(active_faq.question)
        expect(page).to have_content(inactive_faq.question)
      end
    end
  end
end
