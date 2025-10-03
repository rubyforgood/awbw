require "rails_helper"

RSpec.describe "FAQ", type: :system do
  include ActionView::RecordIdentifier

  before do
    create(:permission, :adult)
    create(:permission, :children)
    create(:permission, :combined)
  end

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
        expect(page).to have_selector("##{dom_id(active_faq)}")

        expect(page).not_to have_selector("##{dom_id(inactive_faq)}")
      end
    end

    context "as a super user" do
      let(:super_user) { create(:user, super_user: true) }

      before do
        sign_in super_user
        visit faqs_path
      end

      it "shows both active and inactive FAQs" do
        expect(page).to have_selector("##{dom_id(active_faq)}")
        expect(page).to have_selector("##{dom_id(inactive_faq)}")
      end
    end
  end
end
