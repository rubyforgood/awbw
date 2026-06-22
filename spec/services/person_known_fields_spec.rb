require "rails_helper"

RSpec.describe PersonKnownFields do
  it "returns an empty hash when there is no person" do
    expect(described_class.call(nil)).to eq({})
  end

  it "maps the registrant's on-file identity and contact data to field identifiers" do
    person = create(:person,
                    first_name: "Jordy", legal_first_name: "Jordan", last_name: "Rivera",
                    pronouns: "they/them",
                    email: "jordan@example.com", email_type: "personal",
                    email_2: "jordan.work@example.com", email_2_type: "work")
    person.addresses.create!(
      street_address: "1 Main St", city: "Austin", state: "TX", zip_code: "78701",
      address_type: "personal", locality: "Unknown", primary: true
    )
    person.contact_methods.create!(kind: :phone, value: "555-867-5309", contact_type: "work", primary: true)

    expect(described_class.call(person)).to eq(
      "first_name" => "Jordan",
      "nickname" => "Jordy",
      "last_name" => "Rivera",
      "primary_email" => "jordan@example.com",
      "confirm_email" => "jordan@example.com",
      "primary_email_type" => "Personal",
      "pronouns" => "they/them",
      "secondary_email" => "jordan.work@example.com",
      "secondary_email_type" => "Work",
      "mailing_street" => "1 Main St",
      "mailing_address_type" => "Personal",
      "mailing_city" => "Austin",
      "mailing_state" => "TX",
      "mailing_zip" => "78701",
      "phone" => "555-867-5309",
      "phone_type" => "Work"
    )
  end

  it "uses first_name as the legal name and carries no nickname when none was given" do
    person = create(:person, first_name: "Sam", legal_first_name: nil, last_name: "Doe", email: "sam@example.com")

    result = described_class.call(person)

    expect(result["first_name"]).to eq("Sam")
    expect(result).not_to have_key("nickname")
  end

  it "omits fields the person has no data for" do
    person = create(:person, first_name: "Sam", last_name: "Doe", email: "sam@example.com")

    result = described_class.call(person)

    expect(result).not_to have_key("secondary_email")
    expect(result).not_to have_key("mailing_city")
    expect(result).not_to have_key("phone")
  end

  it "prefers the primary address" do
    person = create(:person, first_name: "Sam", last_name: "Doe", email: "sam@example.com")
    create(:address, addressable: person, city: "Old Town", primary: false)
    create(:address, addressable: person, city: "New Town", primary: true)

    expect(described_class.call(person)["mailing_city"]).to eq("New Town")
  end
end
