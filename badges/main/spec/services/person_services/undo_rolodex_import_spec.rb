# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonServices::UndoRolodexImport do
  around do |example|
    Current.source = "fm_import_people"
    example.run
  ensure
    Current.reset
  end

  let!(:linked) { create(:person, first_name: "Grace", last_name: "Hopper", email: "grace@example.com", filemaker_code: "99999") }

  def rolodex(fm_id, **data)
    FmRolodex.create!(fm_id:, data: { "FirstName" => "Ada", "LastName" => "Lovelace" }.merge(data.stringify_keys))
  end

  def import(run)
    PersonServices::ImportFromRolodex.new(run:).call
  end

  before do
    FmAddress.create!(fm_id: "A300", data: { "RolodexID" => "00300", "AddrsLine1" => "1 Main St",
                                             "AddrsCity" => "Los Angeles", "AddrsState" => "CA" })
    rolodex("00300", EMail: "ada@example.com")
    rolodex("00301", FirstName: "Grace", LastName: "Hopper", EMail: "grace@example.com", Pronouns: "she/her")
    import("run-1")
  end

  it "deletes the people the run created and reverts what it filled in" do
    created = Person.find_by!(filemaker_code: "00300")

    undo = described_class.new(run: "run-1").call

    expect(Person.exists?(created.id)).to be(false)
    expect(Address.where(addressable: created)).to be_empty
    expect(linked.reload).to have_attributes(pronouns: nil, filemaker_code: "99999")
    expect(undo.results[:deleted]).to include("Person ##{created.id}")
  end

  it "keeps a created person someone has edited since" do
    created = Person.find_by!(filemaker_code: "00300")
    travel 1.minute
    created.update!(pronouns: "she/her")

    undo = described_class.new(run: "run-1").call

    expect(Person.exists?(created.id)).to be(true)
    expect(undo.results[:kept]).to include(a_string_including("Person ##{created.id}"))
  end

  it "keeps a filled-in field someone has changed since" do
    linked.reload.update!(pronouns: "they/them")

    described_class.new(run: "run-1").call

    expect(linked.reload).to have_attributes(pronouns: "they/them", filemaker_code: "99999")
  end

  it "leaves another run alone" do
    created = Person.find_by!(filemaker_code: "00300")

    described_class.new(run: "run-2").call

    expect(Person.exists?(created.id)).to be(true)
  end
end
