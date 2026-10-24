# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonServices::CleanupRolodexEmailFlag do
  def rolodex(fm_id, **data)
    FmRolodex.create!(fm_id:, data: { "FirstName" => "Ada", "LastName" => "Lovelace" }.merge(data.stringify_keys))
  end

  def imported_person(fm_id, **attributes)
    person = create(:person, first_name: "Ada", last_name: "Lovelace", filemaker_code: fm_id, user: nil, **attributes)
    create(:ahoy_event, name: "create.person",
                        properties: { resource_type: "Person", resource_id: person.id, source: "fm_import_people" })
    person
  end

  def flag_comment(person, fm_id, *values)
    lines = values.map { |value| "“#{value}”" }
    create(:comment, commentable: person,
                     body: "FileMaker Rolodex #{fm_id} has an email this profile couldn't take:\n#{lines.join("\n")}")
  end

  def cleanup = described_class.new.call

  describe "the flag's comments" do
    it "deletes a comment that quotes only the flag" do
      rolodex("00060", EmailPrimary: "1", EMail: "ada@example.com")
      person = imported_person("00060", email: "ada@example.com")
      flag_comment(person, "00060", "1")

      expect(cleanup.results[:comments_deleted].sole).to include("00060", "##{person.id}")
      expect(person.comments).to be_empty
    end

    it "trims the flag from a comment that also quotes an unusable address" do
      rolodex("00061", EmailPrimary: "2", EMail: "ada@@example.com")
      person = imported_person("00061", email: nil)
      comment = flag_comment(person, "00061", "ada@@example.com", "2")

      expect(cleanup.results[:comments_trimmed].sole).to include("00061")
      expect(comment.reload.body).to eq("FileMaker Rolodex 00061 has an email this profile couldn't take:\n“ada@@example.com”")
    end

    it "leaves comments on rows without the flag alone" do
      rolodex("00062", EMail: "ada@@example.com")
      person = imported_person("00062", email: nil)
      comment = flag_comment(person, "00062", "ada@@example.com")

      cleanup

      expect(comment.reload.body).to include("ada@@example.com")
    end
  end

  describe "rows flagged 2" do
    it "moves an imported person's email to their second email" do
      rolodex("00063", EmailPrimary: "2", EMail: "ada@example.com")
      person = imported_person("00063", email: "ada@example.com", email_type: "work")

      expect(cleanup.results[:moved_to_email_2].sole).to include("00063", "##{person.id}")
      expect(person.reload).to have_attributes(email: nil, email_type: nil, email_2: "ada@example.com", email_2_type: "work")
    end

    it "gives the person a placeholder email when a same-name person has none" do
      create(:person, first_name: "Ada", last_name: "Lovelace", email: nil, user: nil)
      rolodex("00064", EmailPrimary: "2", EMail: "ada@example.com")
      person = imported_person("00064", email: "ada@example.com")

      cleanup

      expect(person.reload).to have_attributes(email: PlaceholderEmail.at(1), email_2: "ada@example.com")
    end

    it "leaves a person the import linked rather than created" do
      rolodex("00065", EmailPrimary: "2", EMail: "ada@example.com")
      person = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", filemaker_code: "00065", user: nil)

      cleanup

      expect(person.reload).to have_attributes(email: "ada@example.com", email_2: nil)
    end

    it "leaves a person who already has a second email" do
      rolodex("00066", EmailPrimary: "2", EMail: "ada@example.com")
      person = imported_person("00066", email: "ada@example.com", email_2: "ada@work.example.com")

      expect(cleanup.results[:kept].sole).to include("00066", "##{person.id}")
      expect(person.reload).to have_attributes(email: "ada@example.com", email_2: "ada@work.example.com")
    end
  end

  describe "rows holding only the flag" do
    it "clears the placeholder email the flag earned the person" do
      create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com")
      rolodex("00067", EmailPrimary: "1")
      person = imported_person("00067", email: PlaceholderEmail.at(1))

      expect(cleanup.results[:placeholders_cleared].sole).to include("00067", "##{person.id}")
      expect(person.reload.email).to be_nil
    end

    it "reports a same-name person with no email the row should have linked" do
      twin = create(:person, first_name: "Ada", last_name: "Lovelace", email: nil, user: nil)
      rolodex("00068", EmailPrimary: "1")
      person = imported_person("00068", email: PlaceholderEmail.at(1))

      expect(cleanup.results[:possible_duplicates].sole).to include("##{person.id}", "##{twin.id}")
      expect(person.reload.email).to eq(PlaceholderEmail.at(1))
    end
  end

  it "changes nothing on a second run" do
    rolodex("00069", EmailPrimary: "2", EMail: "ada@example.com")
    person = imported_person("00069", email: "ada@example.com")
    flag_comment(person, "00069", "2")
    cleanup

    expect(cleanup.results.values).to all(be_empty)
  end
end
