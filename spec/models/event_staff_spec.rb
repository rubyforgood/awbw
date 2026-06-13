require "rails_helper"

RSpec.describe EventStaff, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:event) }
    it { is_expected.to belong_to(:person) }
  end

  describe "validations" do
    subject { build(:event_staff) }

    it "is valid with an event, person, and title" do
      expect(subject).to be_valid
    end

    it "requires a person to be unique per event" do
      existing = create(:event_staff)
      duplicate = build(:event_staff, event: existing.event, person: existing.person)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:person_id]).to be_present
    end

    it "allows the same person on different events" do
      person = create(:person)
      create(:event_staff, person: person)
      other = build(:event_staff, person: person)
      expect(other).to be_valid
    end
  end

  describe "defaults" do
    it "defaults expected_to_attend to false" do
      event_staff = EventStaff.create!(event: create(:event), person: create(:person), title: "Staff")
      expect(event_staff.reload.expected_to_attend).to be(false)
    end
  end

  describe "bio normalization" do
    it "stores a blank bio as nil" do
      event_staff = create(:event_staff, bio: "   ")
      expect(event_staff.bio).to be_nil
    end

    it "strips surrounding whitespace" do
      event_staff = create(:event_staff, bio: "  Hello  ")
      expect(event_staff.bio).to eq("Hello")
    end
  end

  describe "#public_bio" do
    it "returns the event-specific bio when present" do
      person = create(:person, bio: "Profile bio", profile_show_bio: true)
      event_staff = build(:event_staff, person: person, bio: "Event bio")
      expect(event_staff.public_bio).to eq("Event bio")
    end

    it "falls back to the profile bio when no event bio is set and the person allows it" do
      person = create(:person, bio: "Profile bio", profile_show_bio: true)
      event_staff = build(:event_staff, person: person, bio: nil)
      expect(event_staff.public_bio).to eq("Profile bio")
    end

    it "returns nil when the person hides their profile bio and no event bio is set" do
      person = create(:person, bio: "Profile bio", profile_show_bio: false)
      event_staff = build(:event_staff, person: person, bio: nil)
      expect(event_staff.public_bio).to be_nil
    end
  end

  describe ".ordered_by_name" do
    it "orders staff by the person's first then last name" do
      event = create(:event)
      zoe = create(:event_staff, event: event, person: create(:person, first_name: "Zoe", last_name: "Adams"))
      abe = create(:event_staff, event: event, person: create(:person, first_name: "Abe", last_name: "Young"))
      expect(event.event_staffs.ordered_by_name.to_a).to eq([ abe, zoe ])
    end
  end
end
