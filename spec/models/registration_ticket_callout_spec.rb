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

    it "rejects an unknown magic_key" do
      callout.magic_key = "bogus"
      expect(callout).not_to be_valid
      expect(callout.errors[:magic_key]).to be_present
    end

    it "allows only one callout per magic_key within an event" do
      event = create(:event)
      create(:registration_ticket_callout, event:, magic_key: "faq")
      duplicate = build(:registration_ticket_callout, event:, magic_key: "faq")

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:magic_key]).to be_present
    end

    it "allows many custom callouts with a nil magic_key" do
      event = create(:event)
      create(:registration_ticket_callout, event:, magic_key: nil)
      expect(build(:registration_ticket_callout, event:, magic_key: nil)).to be_valid
    end
  end

  describe "scopes and predicates" do
    it "partitions magic and custom callouts and reports #magic?" do
      event = create(:event)
      magic = create(:registration_ticket_callout, event:, magic_key: "faq")
      custom = create(:registration_ticket_callout, event:, magic_key: nil)

      expect(event.registration_ticket_callouts.magic).to eq([ magic ])
      expect(event.registration_ticket_callouts.custom).to eq([ custom ])
      expect(magic.magic?).to be(true)
      expect(custom.magic?).to be(false)
    end

    it "#visible excludes hidden callouts" do
      event = create(:event)
      shown = create(:registration_ticket_callout, event:)
      create(:registration_ticket_callout, :hidden, event:)

      expect(event.registration_ticket_callouts.visible).to eq([ shown ])
    end

    it "treats art_supplies as a content callout (renders its own page), not behavioral" do
      event = create(:event)
      art_supplies = create(:registration_ticket_callout, event:, magic_key: "art_supplies")
      certificate = create(:registration_ticket_callout, event:, magic_key: "certificate")

      expect(art_supplies.behavioral_magic?).to be(false)
      expect(certificate.behavioral_magic?).to be(true)
    end
  end

  describe "#published (inverse of hidden)" do
    it "reads and writes the hidden flag inverted" do
      callout = build(:registration_ticket_callout, hidden: false)
      expect(callout.published).to be(true)

      callout.published = "0"
      expect(callout.hidden).to be(true)
      expect(callout.published).to be(false)

      callout.published = "1"
      expect(callout.hidden).to be(false)
    end
  end

  describe "#dripping?" do
    it "is true only while display_from is in the future" do
      callout.display_from = 1.day.from_now
      expect(callout.dripping?).to be(true)

      callout.display_from = 1.day.ago
      expect(callout.dripping?).to be(false)

      callout.display_from = nil
      expect(callout.dripping?).to be(false)
    end
  end

  describe "linked resources" do
    it "links many resources in order and removes them with the callout" do
      callout = create(:registration_ticket_callout)
      a = create(:resource)
      b = create(:resource)
      callout.resources << a
      callout.resources << b

      expect(callout.reload.resources).to eq([ a, b ])
      expect { callout.destroy }.to change(RegistrationTicketCalloutResource, :count).by(-2)
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
    it "returns the configured colour swatch" do
      callout.color_class = "amber"
      expect(callout.theme).to eq(DomainTheme.swatch("amber"))
    end

    it "falls back to the per-type default colour when blank" do
      callout.color_class = ""
      callout.callout_type = "reference"
      default_color = RegistrationTicketCallout::DEFAULT_COLORS["reference"]
      expect(callout.theme).to eq(DomainTheme.swatch(default_color))
    end
  end
end
