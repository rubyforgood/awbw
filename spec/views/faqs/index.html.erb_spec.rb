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

  context "as an admin in the default (public-facing) view" do
    let(:admin) { build_stubbed(:user, :admin) }

    before do
      allow(view).to receive(:current_user).and_return(admin)
      allow(view).to receive(:allowed_to?).and_return(true)
      allow(view).to receive(:faq_admin_mode?).and_return(false)
      assign(:faqs, paginate_faqs([ faq1, faq2, unpublished_faq ]))
      render
    end

    it "renders every FAQ question" do
      expect(rendered).to have_css("##{dom_id(faq1)}", text: faq1.question)
      expect(rendered).to have_css("##{dom_id(faq2)}", text: faq2.question)
      expect(rendered).to have_css("##{dom_id(unpublished_faq)}", text: unpublished_faq.question)
    end

    it "hides the admin edit controls" do
      expect(rendered).not_to include("data-sortable-handle")
      expect(rendered).not_to have_css("i.fa-toggle-on, i.fa-toggle-off")
      expect(rendered).not_to include("Confirm: Delete FAQ?")
    end

    it "shows the New FAQ button and an Admin mode link" do
      expect(rendered).to include("New FAQ")
      expect(rendered).to have_link("Admin mode")
      expect(rendered).not_to have_link("Exit admin mode")
    end
  end

  context "as an admin in admin mode" do
    let(:admin) { build_stubbed(:user, :admin) }

    before do
      allow(view).to receive(:current_user).and_return(admin)
      allow(view).to receive(:allowed_to?).and_return(true)
      allow(view).to receive(:faq_admin_mode?).and_return(true)
      assign(:faqs, paginate_faqs([ faq1, faq2, unpublished_faq ]))
      render
    end

    it "shows the reorder handle, visibility toggles, and delete control" do
      expect(rendered).to include("data-sortable-handle")
      expect(rendered).to have_css("i.fa-toggle-on, i.fa-toggle-off")
      expect(rendered).to include("Confirm: Delete FAQ?")
    end

    it "swaps the toggle for an Exit admin mode link" do
      expect(rendered).to have_link("Exit admin mode")
      expect(rendered).not_to have_link("Admin mode")
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

    it "does not show an Admin mode link" do
      expect(rendered).not_to have_link("Admin mode")
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
