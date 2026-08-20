require "rails_helper"

RSpec.describe PersonHelper, type: :helper do
  describe "#person_profile_button" do
    let(:person) { create(:person, user: create(:user, unconfirmed_email: unconfirmed)) }

    before do
      allow(helper).to receive(:allowed_to?).with(:show_email_change?, person).and_return(authorized)
    end

    context "when an email change is pending and the viewer may see it" do
      let(:unconfirmed) { "new@example.com" }
      let(:authorized) { true }

      it "renders the pending email-change warning with the new address" do
        html = helper.person_profile_button(person)

        expect(html).to include("fa-triangle-exclamation")
        expect(html).to include("new@example.com")
      end
    end

    context "when the viewer may not see the change" do
      let(:unconfirmed) { "new@example.com" }
      let(:authorized) { false }

      it "omits the warning" do
        expect(helper.person_profile_button(person)).not_to include("fa-triangle-exclamation")
      end
    end

    context "when no email change is pending" do
      let(:unconfirmed) { nil }
      let(:authorized) { true }

      it "omits the warning" do
        expect(helper.person_profile_button(person)).not_to include("fa-triangle-exclamation")
      end
    end
  end
end
