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

    context "frame breakout" do
      let(:unconfirmed) { nil }
      let(:authorized) { true }

      it "forwards a caller's data-turbo-frame onto the link so call sites can break out of a frame" do
        link = Nokogiri::HTML(
          helper.person_profile_button(person, data: { turbo_frame: "_top" })
        ).at_css("a")
        expect(link["data-turbo-frame"]).to eq("_top")
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

    it "shows the full name even when the person's display preference is abbreviated" do
      person.update!(display_name_preference: "first_name_only")

      expect(helper.person_edit_button(person)).to include("Aisha Sharma")
    end

    it "renders the email subtitle when given" do
      expect(helper.person_edit_button(person, subtitle: "aisha@example.com")).to include("aisha@example.com")
    end

    it "reads inline in :prefix layout and stacks in :eyebrow layout" do
      expect(helper.person_edit_button(person, layout: :prefix)).to include("items-baseline gap-1.5")
      expect(helper.person_edit_button(person, layout: :eyebrow)).not_to include("items-baseline gap-1.5")
    end

    it "forwards a caller's data-turbo-frame onto the link so call sites can break out of a frame" do
      link = Nokogiri::HTML(helper.person_edit_button(person, data: { turbo_frame: "_top" })).at_css("a")
      expect(link["data-turbo-frame"]).to eq("_top")
    end
  end

  describe "#user_button" do
    let(:user) { create(:user, person: create(:person, first_name: "Cara", last_name: "Lang")) }

    it "links to the user's show page for a viewer who may see it" do
      allow(helper).to receive(:allowed_to?).with(:show?, user).and_return(true)
      html = helper.user_button(user)

      expect(html).to include(%(href="#{user_path(user)}"))
      expect(html).to include("Cara Lang")
    end

    it "renders a plain name, not a link, when the viewer may not see the user" do
      allow(helper).to receive(:allowed_to?).with(:show?, user).and_return(false)
      html = helper.user_button(user)

      expect(html).not_to include("href=")
      expect(html).to include("Cara Lang")
    end

    it "forwards a caller's data-turbo-frame onto the link so call sites can break out of a frame" do
      allow(helper).to receive(:allowed_to?).with(:show?, user).and_return(true)
      link = Nokogiri::HTML(helper.user_button(user, data: { turbo_frame: "_top" })).at_css("a")
      expect(link["data-turbo-frame"]).to eq("_top")
    end
  end

  describe "#user_link" do
    let(:user) { create(:user, person: create(:person, first_name: "Cara", last_name: "Lang")) }

    it "renders a plain text link to the user's show page for a viewer who may see it" do
      allow(helper).to receive(:allowed_to?).with(:show?, user).and_return(true)
      link = Nokogiri::HTML(helper.user_link(user)).at_css("a")

      expect(link["href"]).to eq(user_path(user))
      expect(link.text).to eq("Cara Lang")
      expect(link["class"]).to include("hover:underline")
    end

    it "renders a plain name, not a link, when the viewer may not see the user" do
      allow(helper).to receive(:allowed_to?).with(:show?, user).and_return(false)
      html = helper.user_link(user)

      expect(html).not_to include("href=")
      expect(html).to include("Cara Lang")
    end
  end
end
