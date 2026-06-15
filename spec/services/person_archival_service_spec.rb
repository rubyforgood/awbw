require "rails_helper"

RSpec.describe PersonArchivalService do
  describe "#archive!" do
    it "discards the person and their user together" do
      person = create(:person)
      user = person.user

      described_class.new(person).archive!

      expect(person.reload).to be_discarded
      expect(user.reload).to be_discarded
    end

    it "discards a person without a user" do
      person = create(:person, user: nil)

      described_class.new(person).archive!

      expect(person.reload).to be_discarded
    end

    it "blocks a discarded user from authenticating" do
      person = create(:person)

      described_class.new(person).archive!

      expect(person.user.reload.active_for_authentication?).to be false
    end
  end

  describe "#restore!" do
    it "undiscards the person and their user together" do
      person = create(:person)
      user = person.user
      described_class.new(person).archive!

      described_class.new(person).restore!

      expect(person.reload).to be_kept
      expect(user.reload).to be_kept
    end
  end
end
