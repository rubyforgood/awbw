require "rails_helper"

RSpec.describe "FAQ", type: :system do
  include ActionView::RecordIdentifier

  let!(:published_faq) { create(:faq, published: true) }
  let!(:unpublished_faq) { create(:faq, published: false) }

  context "Index" do
    context "as a regular user" do
      let(:user) { create(:user) }

      before do
        sign_in user
        visit faqs_path
      end

      it "shows only published FAQs" do
        expect(page).to have_content(published_faq.question)
        expect(page).not_to have_content(unpublished_faq.question)
      end
    end

    context "as an admin" do
      let(:admin) { create(:user, :admin) }

      before do
        sign_in admin
        visit faqs_path
      end

      it "shows both published and unpublished FAQs" do
        expect(page).to have_content(published_faq.question)
        expect(page).to have_content(unpublished_faq.question)
      end
    end
  end
end
