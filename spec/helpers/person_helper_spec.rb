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

  describe "#person_edit_button" do
    let(:person) { create(:person, first_name: "Aisha", last_name: "Sharma") }

    it "links to the person's edit page, not the profile" do
      html = helper.person_edit_button(person)

      expect(html).to include(%(href="#{edit_person_path(person)}"))
      expect(html).not_to include(%(href="#{person_path(person)}"))
    end

    it "reads 'Edit' before the person's name and shows no avatar" do
      html = helper.person_edit_button(person)

      expect(html).to include("Edit")
      expect(html).to include("Aisha Sharma")
      expect(html).not_to include("rounded-full")
    end

    it "renders the email subtitle when given" do
      expect(helper.person_edit_button(person, subtitle: "aisha@example.com")).to include("aisha@example.com")
    end

    it "reads inline in :prefix layout and stacks in :eyebrow layout" do
      expect(helper.person_edit_button(person, layout: :prefix)).to include("items-baseline gap-1.5")
      expect(helper.person_edit_button(person, layout: :eyebrow)).not_to include("items-baseline gap-1.5")
    end
  end
end
