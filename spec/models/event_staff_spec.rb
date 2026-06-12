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

  describe ".ordered_by_name" do
    it "orders staff by the person's first then last name" do
      event = create(:event)
      zoe = create(:event_staff, event: event, person: create(:person, first_name: "Zoe", last_name: "Adams"))
      abe = create(:event_staff, event: event, person: create(:person, first_name: "Abe", last_name: "Young"))
      expect(event.event_staffs.ordered_by_name.to_a).to eq([ abe, zoe ])
    end
  end
end
