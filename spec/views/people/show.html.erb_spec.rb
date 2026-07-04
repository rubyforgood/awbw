require 'rails_helper'

RSpec.describe "people/show", type: :view do
  let(:admin) { create(:user, :admin) }

  let(:person) { create(:person) }

  before do
    assign(:person, person.decorate)
    allow(view).to receive(:current_user).and_return(admin)
    allow(view).to receive(:allowed_to?).and_return(false)
  end

  describe "attributes" do
    before { render }

    it "renders attributes" do
      expect(rendered).to match(person.first_name)
      expect(rendered).to match(person.last_name)
      expect(rendered).to match(person.user.email)
    end
  end

  describe "pending email-change chip" do
    context "when the viewer is authorized to see the email change" do
      before do
        allow(view).to receive(:allowed_to?).with(:show_email_change?, anything).and_return(true)
      end

      context "and the user has a pending email change" do
        let(:person) { create(:person, user: create(:user, unconfirmed_email: "changed@example.com")) }

        before { render }

        it "renders the chip and the pending address inline" do
          expect(rendered).to include("Email change to")
          expect(rendered).to include("changed@example.com")
        end
      end

      context "and the user has no pending email change" do
        before { render }

        it "does not render the chip" do
          expect(rendered).not_to include("Email change to")
        end
      end
    end

    context "when the viewer is not authorized to see the email change" do
      let(:person) { create(:person, user: create(:user, unconfirmed_email: "changed@example.com")) }

      before { render }

      it "does not render the chip or leak the pending address" do
        expect(rendered).not_to include("Email change to")
        expect(rendered).not_to include("changed@example.com")
      end
    end
  end
end
