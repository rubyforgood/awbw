require "rails_helper"

RSpec.describe "FAQ visibility", type: :system do
  let!(:published_faq)   { create(:faq, :published) }
  let!(:unpublished_faq) { create(:faq) }
  let!(:public_faq) { create(:faq, :publicly_visible, :published) }

  describe "index page" do
    context "as a regular user" do
      before do
        sign_in create(:user)
        visit faqs_path
      end

      it "shows only published FAQs" do
        expect(page).to have_text(published_faq.question)
        expect(page).not_to have_text(unpublished_faq.question)
      end

      it "does not show admin controls" do
        expect(page).not_to have_link("New FAQ")
      end
    end

    context "as an admin" do
      before do
        sign_in create(:user, :admin)
        visit faqs_path
      end

      it "shows all FAQs" do
        expect(page).to have_text(published_faq.question)
        expect(page).to have_text(unpublished_faq.question)
      end

      it "shows admin controls" do
        expect(page).to have_link("New FAQ")
      end
    end

    context "as a guest" do
      before do
        visit faqs_path
      end

      it "shows only public FAQs" do
        expect(page).to have_text(public_faq.question)
        expect(page).not_to have_text(published_faq.question)
        expect(page).not_to have_text(unpublished_faq.question)
      end

      it "does not show admin controls" do
        expect(page).not_to have_link("Edit")
      end
    end
  end
end
