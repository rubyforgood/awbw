require "rails_helper"

RSpec.describe "Work addresses and address phones on the person edit form", type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, name: "Sunrise Center") }
  let(:work_address) { create(:address, addressable: organization, street_address: "9 Oak Ave", phone: "555-010-0000") }

  def addresses_section = Capybara.string(response.body).find("#addresses")

  before do
    create(:affiliation, person: person, organization: organization, organization_address: work_address)
  end

  context "as an admin" do
    before { sign_in create(:user, :admin) }

    it "shows the linked work address read-only, linking to it on the organization" do
      get edit_person_path(person)

      expect(addresses_section).to have_text("9 Oak Ave")
      expect(addresses_section).to have_text("at Sunrise Center")
      expect(addresses_section).to have_text("555-010-0000")
      expect(addresses_section).to have_link("Edit on organization",
                                             href: edit_organization_path(organization, highlight_address: work_address.id, return_to: "person_edit",
                                                                                        person_id: person.id, anchor: "address-#{work_address.id}"))
      expect(addresses_section).not_to have_field(with: "9 Oak Ave")
    end

    it "lists mailing-address phones missing from the phones list" do
      create(:address, addressable: person, phone: "555-020-0000")

      get edit_person_path(person)

      phones = Capybara.string(response.body).find("#phones")
      expect(phones).to have_text("On addresses")
      expect(phones).to have_text("555-020-0000")
    end

    it "lists the linked work address phone under the phones, with its organization" do
      get edit_person_path(person)

      phones = Capybara.string(response.body).find("#phones")
      expect(phones).to have_css("li", text: /Work\s+555-010-0000\s+at Sunrise Center/)
    end
  end

  context "as the owner" do
    before do
      sign_in create(:user, person: person)
      allow_any_instance_of(PersonPolicy).to receive(:edit?).and_return(true)
    end

    it "links the work address to a change request" do
      get edit_person_path(person)

      expect(addresses_section).to have_text("9 Oak Ave")
      expect(addresses_section).to have_css("a[href*='field=affiliation']", text: "Request a change")
      expect(addresses_section).not_to have_link("Edit on organization")
    end
  end
end
