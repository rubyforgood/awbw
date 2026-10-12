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

  it "prefixes the street number when the first line doesn't already carry it" do
    FmAddress.create!(fm_id: "A2", data: { "StreetNo" => "1234", "AddrsLine1" => "Main St",
                                           "AddrsCity" => "Los Angeles", "AddrsState" => "CA" })
    FmAddress.create!(fm_id: "A3", data: { "StreetNo" => "1234", "AddrsLine1" => "1234 Main St",
                                           "AddrsCity" => "Los Angeles", "AddrsState" => "CA" })
    rolodex("00030", FirstName: "Grace", EMail: "grace@example.com", PrimaryAddrsID: "A2")
    rolodex("00031", FirstName: "Hedy", EMail: "hedy@example.com", PrimaryAddrsID: "A3")

    results

    expect(Person.find_by!(filemaker_code: "00030").addresses.sole.street_address).to eq("1234 Main St")
    expect(Person.find_by!(filemaker_code: "00031").addresses.sole.street_address).to eq("1234 Main St")
  end

  it "truncates over-long free text instead of losing the person to it" do
    FmAddress.create!(fm_id: "A4", data: { "AddrsLine1" => "x" * 200, "AddrsLine2" => "y" * 200,
                                           "AddrsCity" => "Los Angeles", "AddrsState" => "CA" })
    rolodex("00032", EMail: "ada@example.com", BestTimeToCall: "z" * 300, PrimaryAddrsID: "A4")

    expect(results[:failed]).to be_empty

    person = Person.find_by!(filemaker_code: "00032")
    expect(person.best_time_to_call.length).to eq(255)
    expect(person.addresses.sole.street_address.length).to eq(255)
  end

  it "types a phone the contact method can't take as unknown, keeping it on the address" do
    FmAddress.create!(fm_id: "A5", data: { "AddrsLine1" => "1 Main St", "AddrsCity" => "Los Angeles",
                                           "AddrsState" => "CA", "AddrsType" => "Mailing" })
    FmPhoneNumber.create!(fm_id: "P2", data: { "PhoneNumber" => "555-0100", "PhoneType" => "Mailing" })
    FmPhoneNumber.create!(fm_id: "P3", data: { "PhoneNumber" => "555-0200", "PhoneType" => "Cell" })
    rolodex("00033", EMail: "ada@example.com", PrimaryAddrsID: "A5", PrimaryPhoneID: "P2")
    rolodex("00034", FirstName: "Grace", EMail: "grace@example.com", PrimaryPhoneID: "P3")

    results

    mailing = Person.find_by!(filemaker_code: "00033")
    expect(mailing.addresses.sole.address_type).to eq("mailing")
    expect(mailing.contact_methods.sole.contact_type).to eq("unknown")
    expect(Person.find_by!(filemaker_code: "00034").contact_methods.sole.contact_type).to eq("personal")
  end

  it "types an address and phone the archive left blank as unknown" do
    FmAddress.create!(fm_id: "A6", data: { "AddrsLine1" => "1 Main St", "AddrsCity" => "Los Angeles", "AddrsState" => "CA" })
    FmPhoneNumber.create!(fm_id: "P4", data: { "PhoneNumber" => "555-0300" })
    rolodex("00035", EMail: "ada@example.com", PrimaryAddrsID: "A6", PrimaryPhoneID: "P4")

    results

    person = Person.find_by!(filemaker_code: "00035")
    expect(person.addresses.sole.address_type).to eq("unknown")
    expect(person.contact_methods.sole.contact_type).to eq("unknown")
  end

  it "reads the archive's date formats, giving a two-digit year its century" do
    rolodex("00020", FirstName: "Grace", EMail: "grace@example.com", DateOfBirth: "10/5/83")
    rolodex("00021", FirstName: "Katherine", EMail: "katherine@example.com", DateOfBirth: "3/4/05")
    rolodex("00022", FirstName: "Hedy", EMail: "hedy@example.com", DateOfBirth: "10-5-1983")
    rolodex("00023", FirstName: "Mary", EMail: "mary@example.com", DateOfBirth: "1983/10/05")

    results

    expect(Person.find_by!(filemaker_code: "00020").date_of_birth).to eq(Date.new(1983, 10, 5))
    expect(Person.find_by!(filemaker_code: "00021").date_of_birth).to eq(Date.new(2005, 3, 4))
    expect(Person.find_by!(filemaker_code: "00022").date_of_birth).to eq(Date.new(1983, 10, 5))
    expect(Person.find_by!(filemaker_code: "00023").date_of_birth).to eq(Date.new(1983, 10, 5))
  end

  it "links an existing person with the same name and email instead of creating one" do
    person = create(:person, first_name: "ada", last_name: "LOVELACE", email: "Ada@Example.com")
    rolodex("00008", EMail: "ada@example.com")

    expect { results }.not_to change(Person, :count)
    expect(person.reload.filemaker_code).to eq("00008")
  end

  it "links a person the archive knows by their login email" do
    person = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada.l@example.com")
    # Bypassing the sync leaves the login address the person's own columns never got,
    # which is the legacy shape PersonMatcher reaches.
    person.user.update_columns(email: "ada@example.com")
    rolodex("00040", EMail: "ada@example.com")

    expect { results }.not_to change(Person, :count)
    expect(person.reload.filemaker_code).to eq("00040")
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
    # A linked login would become their primary email (PersonLoginEmailSync), so the
    # person this guards against is one with no account.
    create(:person, first_name: "Ada", last_name: "Lovelace", email: nil, user: nil)
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
