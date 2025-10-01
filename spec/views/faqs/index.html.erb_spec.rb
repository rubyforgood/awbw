require "rails_helper"

RSpec.describe "faqs/index", type: :view do
  let!(:faq1) { create(:faq, question: "What is Festi?", answer: "An all-in-one platform") }
  let!(:faq2) { create(:faq, question: "How do I sign up?", answer: "Click the signup button") }
  let!(:inactive_faq) { create(:faq, question: "Inactive FAQ", answer: "You shouldn't see me", inactive: true) }

  # Build a fake paginated collection
  def paginate_faqs(faqs)
    WillPaginate::Collection.create(1, faqs.size, faqs.size) do |pager|
      pager.replace(faqs)
    end
  end

  context "as a super user" do
    let(:super_user) { build_stubbed(:user, super_user: true) }

    before do
      allow(view).to receive(:current_user).and_return(super_user)

      assign(:faqs, paginate_faqs([faq1, faq2, inactive_faq]))
    end

    it "renders all FAQ divs including the inactive status for inactive FAQs" do
      render

      expect(rendered).to have_css("##{dom_id(faq1)}", text: faq1.question)
      expect(rendered).to have_css("##{dom_id(faq2)}", text: faq2.question)

      expect(rendered).to have_css("##{dom_id(inactive_faq)}", text: inactive_faq.question)

      within("##{dom_id(inactive_faq)}") do
        expect(rendered).to have_selector("strong", text: "Inactive:")
        expect(rendered).to include(inactive_faq.inactive.to_s)
      end
    end
  end

  context "as a regular user" do
    let(:regular_user) { build_stubbed(:user, super_user: false) }

    before do
      allow(view).to receive(:current_user).and_return(regular_user)

      assign(:faqs, paginate_faqs([faq1, faq2]))
    end

    it "renders only active FAQ divs" do
      render

      expect(rendered).to have_css("##{dom_id(faq1)}", text: faq1.question)
      expect(rendered).to have_css("##{dom_id(faq2)}", text: faq2.question)

      expect(rendered).not_to have_css("##{dom_id(inactive_faq)}", text: inactive_faq.question)
    end
  end
end
