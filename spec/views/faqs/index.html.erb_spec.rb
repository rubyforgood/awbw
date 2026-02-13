require "rails_helper"

RSpec.describe "faqs/index", type: :view do
  let!(:faq1) { create(:faq, question: "What is Festi?", answer: "An all-in-one platform") }
  let!(:faq2) { create(:faq, question: "How do I sign up?", answer: "Click the signup button") }
  let!(:unpublished_faq) { create(:faq, question: "Unpublished FAQ", answer: "You shouldn't see me", published: false) }

  # Build a fake paginated collection
  def paginate_faqs(faqs)
    WillPaginate::Collection.create(1, faqs.size, faqs.size) do |pager|
      pager.replace(faqs)
    end
  end

  context "as an admin" do
    let(:admin) { build_stubbed(:user, :admin) }

    before do
      allow(view).to receive(:current_user).and_return(admin)
      allow(view).to receive(:allowed_to?).and_return(true)
      assign(:faqs, paginate_faqs([ faq1, faq2, unpublished_faq ]))
      render
    end

    it "renders all FAQ divs including the unpublished status for unpublished FAQs" do
      expect(rendered).to have_css("##{dom_id(faq1)}", text: faq1.question)
      expect(rendered).to have_css("##{dom_id(faq2)}", text: faq2.question)

      expect(rendered).to have_css("##{dom_id(unpublished_faq)}", text: unpublished_faq.question)

      within("##{dom_id(unpublished_faq)}") do
        expect(rendered).to have_selector("strong", text: "Unpublished:")
        expect(rendered).to include(unpublished_faq.unpublished.to_s)
      end
    end

    it "shows New FAQ button for admin" do
      expect(rendered).to include("New FAQ")
    end
  end

  context "as a regular user" do
    let(:regular_user) { build_stubbed(:user) }

    before do
      allow(view).to receive(:current_user).and_return(regular_user)

      assign(:faqs, paginate_faqs([ faq1, faq2 ]))
      render
    end

    it "renders only published FAQ divs" do
      expect(rendered).to have_css("##{dom_id(faq1)}", text: faq1.question)
      expect(rendered).to have_css("##{dom_id(faq2)}", text: faq2.question)

      expect(rendered).not_to have_css("##{dom_id(unpublished_faq)}", text: unpublished_faq.question)
    end

    it "does not New FAQ button for regular_user" do
      expect(rendered).to_not include("New FAQ")
    end
  end

  context "as any user" do
    let(:regular_user) { build_stubbed(:user) }

    before do
      allow(view).to receive(:current_user).and_return(regular_user)
      assign(:faqs, paginate_faqs([ faq1, faq2 ]))
      render
    end

    it "renders search form" do
      expect(rendered).to have_selector("form[action='#{faqs_path}'][method='get']")
    end
  end
end
