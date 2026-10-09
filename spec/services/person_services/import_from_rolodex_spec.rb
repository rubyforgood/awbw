# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonServices::ImportFromRolodex do
  def rolodex(fm_id, **data)
    FmRolodex.create!(fm_id:, data: { "FirstName" => "Ada", "LastName" => "Lovelace" }.merge(data.stringify_keys))
  end

  def results
    described_class.new.call.results
  end

  it "creates a person with profile fields, primary address, and primary phone" do
    FmAddress.create!(fm_id: "A1", data: { "AddrsLine1" => "1 Main St", "AddrsLine2" => "Apt 2", "AddrsCity" => "Los Angeles",
                                           "AddrsState" => "CA", "AddrsPostalCode" => "90001", "AddrsType" => "Home" })
    FmPhoneNumber.create!(fm_id: "P1", data: { "PhoneNumber" => "555-0100", "PhoneType" => "Work" })
    rolodex("00006", EMail: "ada@example.com", Pronouns: "she/her", DateOfBirth: "12/10/1815",
                     Comments: "Met at training", PrimaryAddrsID: "A1", PrimaryPhoneID: "P1")

    expect(results[:created].size).to eq(1)

    person = Person.find_by!(filemaker_code: "00006")
    expect(person).to have_attributes(first_name: "Ada", last_name: "Lovelace", email: "ada@example.com",
                                      pronouns: "she/her", date_of_birth: Date.new(1815, 12, 10), notes: "Met at training")
    expect(person.addresses.sole).to have_attributes(street_address: "1 Main St, Apt 2", city: "Los Angeles", state: "CA",
                                                     zip_code: "90001", address_type: "personal", locality: "Unknown", primary: true)
    expect(person.contact_methods.sole).to have_attributes(kind: "phone", value: "555-0100", contact_type: "work", primary: true)
  end

  it "splits two emails in one field into email and email_2" do
    rolodex("00007", EMail: "ada@example.com; ada@work.example.com")

    results

    expect(Person.find_by!(filemaker_code: "00007")).to have_attributes(email: "ada@example.com", email_2: "ada@work.example.com")
  end

  it "links an existing person with the same name and email instead of creating one" do
    person = create(:person, first_name: "ada", last_name: "LOVELACE", email: "Ada@Example.com")
    rolodex("00008", EMail: "ada@example.com")

    expect { results }.not_to change(Person, :count)
    expect(person.reload.filemaker_code).to eq("00008")
  end

  it "leaves rows whose ID a person already carries alone" do
    create(:person, filemaker_code: "00009")
    rolodex("00009")

    expect(results[:already_imported].size).to eq(1)
    expect(Person.where(filemaker_code: "00009").count).to eq(1)
  end

  it "flags an email that belongs to a differently named person" do
    create(:person, first_name: "Charles", last_name: "Babbage", email: "ada@example.com")
    rolodex("00010", EMail: "ada@example.com")

    expect { expect(results[:ambiguous].size).to eq(1) }.not_to change(Person, :count)
  end

  it "flags a same-name match with no email to confirm it" do
    create(:person, first_name: "Ada", last_name: "Lovelace", email: nil)
    rolodex("00011")

    expect { expect(results[:ambiguous].size).to eq(1) }.not_to change(Person, :count)
  end

  it "flags a name + email match already linked to another FileMaker record" do
    person = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", filemaker_code: "99999")
    rolodex("00012", EMail: "ada@example.com")

    expect(results[:ambiguous].size).to eq(1)
    expect(person.reload.filemaker_code).to eq("99999")
  end

  it "skips agencies, deleted rows, and nameless rows" do
    rolodex("00013", isAgency__c: "1")
    rolodex("00014", Delete: "Yes")
    rolodex("00015", FirstName: "", LastName: "")

    expect(results[:skipped].size).to eq(3)
    expect(Person.where(filemaker_code: %w[00013 00014 00015])).to be_empty
  end

  it "treats a false-y flag as unset" do
    rolodex("00016", isAgency__c: "0", Delete: "No")

    expect(results[:created].size).to eq(1)
  end

  it "doesn't create the same person twice when the import reruns" do
    rolodex("00017", EMail: "ada@example.com")

    described_class.new.call

    expect { results }.not_to change(Person, :count)
  end
end
