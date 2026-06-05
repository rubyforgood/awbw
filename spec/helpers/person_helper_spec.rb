require "rails_helper"

RSpec.describe PersonHelper, type: :helper do
  describe "#person_select_options" do
    it "shows only the name when the full name is unique" do
      amy = create(:person, first_name: "Amy", last_name: "User", email: "amy@example.com")
      ben = create(:person, first_name: "Ben", last_name: "Smith", email: "ben@example.com")

      options = helper.person_select_options([ amy, ben ])

      expect(options).to contain_exactly([ "Amy User", amy.id ], [ "Ben Smith", ben.id ])
    end

    it "appends the email only for people who share a full name" do
      amy_one = create(:person, first_name: "Amy", last_name: "User", email: "amy.one@example.com")
      amy_two = create(:person, first_name: "Amy", last_name: "User", email: "amy.two@example.com")
      ben = create(:person, first_name: "Ben", last_name: "Smith", email: "ben@example.com")

      options = helper.person_select_options([ amy_one, amy_two, ben ])

      expect(options).to contain_exactly(
        [ amy_one.full_name_with_email, amy_one.id ],
        [ amy_two.full_name_with_email, amy_two.id ],
        [ "Ben Smith", ben.id ]
      )
      expect(amy_one.full_name_with_email).to include("(")
    end
  end
end
