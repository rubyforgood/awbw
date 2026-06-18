require "rails_helper"

RSpec.describe RegistrationTicketCallout, type: :model do
  subject(:callout) { build(:registration_ticket_callout) }

  it "has a valid factory" do
    expect(callout).to be_valid
  end

  describe "validations" do
    it "requires a title" do
      callout.title = ""
      expect(callout).not_to be_valid
      expect(callout.errors[:title]).to be_present
    end

    it "requires a known callout_type" do
      callout.callout_type = "bogus"
      expect(callout).not_to be_valid
      expect(callout.errors[:callout_type]).to be_present
    end

    it "allows a blank colour but rejects an unknown one" do
      callout.color_class = ""
      expect(callout).to be_valid

      callout.color_class = "chartreuse"
      expect(callout).not_to be_valid
    end
  end

  describe "positioning" do
    it "assigns sequential positions in creation order" do
      event = create(:event)
      a = create(:registration_ticket_callout, event:)
      b = create(:registration_ticket_callout, event:)
      c = create(:registration_ticket_callout, event:)

      expect([ a.position, b.position, c.position ]).to eq([ 1, 2, 3 ])
    end

    it "reflows the others when a callout is moved, and #ordered reflects it" do
      event = create(:event)
      a = create(:registration_ticket_callout, event:)
      b = create(:registration_ticket_callout, event:)
      c = create(:registration_ticket_callout, event:)

      c.update!(position: 1)

      expect(event.registration_ticket_callouts.ordered).to eq([ c, a, b ])
    end
  end

  describe "#display_icon_class" do
    it "uses the configured icon when present" do
      callout.icon_class = "fa-solid fa-car"
      expect(callout.display_icon_class).to eq("fa-solid fa-car")
    end

    it "falls back to a per-type default when blank" do
      callout.icon_class = ""
      callout.callout_type = "action"
      expect(callout.display_icon_class).to eq(RegistrationTicketCallout::DEFAULT_ICONS["action"])
    end
  end

  describe "#theme" do
    it "returns the configured colour theme" do
      callout.color_class = "amber"
      expect(callout.theme).to eq(RegistrationTicketCallout::COLOR_THEMES["amber"])
    end

    it "falls back to the per-type default colour when blank" do
      callout.color_class = ""
      callout.callout_type = "reference"
      default_key = RegistrationTicketCallout::DEFAULT_COLORS["reference"]
      expect(callout.theme).to eq(RegistrationTicketCallout::COLOR_THEMES[default_key])
    end
  end
end
