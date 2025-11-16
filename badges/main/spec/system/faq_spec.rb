require "rails_helper"

RSpec.describe "FAQ", type: :system do
  include ActionView::RecordIdentifier

  let!(:active_faq) { create(:faq, inactive: false) }
  let!(:inactive_faq) { create(:faq, inactive: true) }

  context "Index" do
    context "as a regular user" do
      let(:user) { create(:user, super_user: false) }

      before do
        sign_in user
        visit faqs_path
      end

      it "shows only active FAQs" do
        expect(page).to have_content(active_faq.question)
        expect(page).not_to have_content(inactive_faq.question)
      end
    end

    context "as a super user" do
      let(:super_user) { create(:user, super_user: true) }

      before do
        sign_in super_user
        visit faqs_path
      end

      it "shows both active and inactive FAQs" do
        expect(page).to have_content(active_faq.question)
        expect(page).to have_content(inactive_faq.question)
      end
    end
  end
end
