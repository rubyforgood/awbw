require "rails_helper"

# The simple "Edit my profile" page saves through PeopleController#update as
# the owner, so it must survive the owner params filter, skip its blank add-new
# rows, and land on the person's change log.
RSpec.describe "Editing your own profile details", type: :request do
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }
  let!(:arts) { create(:sector, :published, name: "Arts") }
  let!(:health) { create(:sector, :published, name: "Health") }

  before do
    Analytics::LifecycleBuffer.store.clear
    sign_in owner_user
  end

  after { Current.user = nil }

  def save_details(attributes)
    patch person_path(person), params: { return_to: "details", person: attributes }
  end

  # The controller flushes (and clears) the buffer in an after_action, so copy
  # the events as it flushes.
  def buffered_during_request
    events = []
    allow(Analytics::LifecycleBuffer).to receive(:flush) do
      events.concat(Analytics::LifecycleBuffer.store)
      Analytics::LifecycleBuffer.store.clear
    end
    yield
    events
  end

  it "shows every section" do
    get details_person_path(person)

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Your photo", "Your name", "About you", "Phone", "Mailing address",
                                      "Social media", "Sectors you work in", "Arts", "Health")
    expect(response.body).not_to include("person[email]", "person[filemaker_code]", "person[profile_show_email]")
  end

  it "links to a contact form prefilled for a profile question" do
    get details_person_path(person)

    expect(response.body).to include("Ask a question")
    expect(response.body).to include(contact_us_path(subject: "Question about my profile", return_to: "person_details").gsub("&", "&amp;"))
  end

  it "has the contact form lead back to the edit page" do
    get contact_us_path(subject: "Question about my profile", return_to: "person_details")

    expect(response.body).to include(%(value="Question about my profile"))
    expect(response.body).to include("Back to editing my profile", details_person_path(person))
  end

  it "saves and returns to the profile" do
    save_details(first_name: "Jordan", pronouns: "they/them", bio: "I teach art.", linked_in_url: "https://linkedin.com/in/x")

    expect(response).to redirect_to(person_path(person))
    expect(person.reload).to have_attributes(first_name: "Jordan", pronouns: "they/them", bio: "I teach art.",
                                             linked_in_url: "https://linkedin.com/in/x")
  end

  it "ignores the blank add-new rows when nothing is filled in" do
    expect {
      save_details(
        first_name: person.first_name,
        contact_methods_attributes: { "999" => { kind: "phone", value: "", contact_type: "" } },
        addresses_attributes: { "0" => { street_address: "", city: "", state: "", zip_code: "", locality: "" } },
        sectorable_items_attributes: { "0" => { sector_id: arts.id, _destroy: "1" } },
        professional_licenses_attributes: { "999" => { kind: "", number: "", issuing_state: "", expires_on: "" } }
      )
    }.not_to change { [ person.contact_methods.count, person.addresses.count, person.sectorable_items.count, person.professional_licenses.count ] }

    expect(response).to redirect_to(person_path(person))
  end

  it "adds and removes sectors from the checkboxes" do
    existing = create(:sectorable_item, sectorable: person, sector: arts)

    save_details(sectorable_items_attributes: {
      "0" => { id: existing.id, sector_id: arts.id, _destroy: "1" },
      "1" => { sector_id: health.id, _destroy: "0" }
    })

    expect(person.reload.sectors).to contain_exactly(health)
  end

  it "stars the current main sector" do
    create(:sectorable_item, sectorable: person, sector: arts, is_primary: true)
    create(:sectorable_item, sectorable: person, sector: health)

    get details_person_path(person)

    expect(response.body).to match(/<input[^>]*checked="checked"[^>]*name="person\[sectorable_items_attributes\]\[0\]\[is_primary\]"/)
    expect(response.body).not_to match(/<input[^>]*checked="checked"[^>]*name="person\[sectorable_items_attributes\]\[1\]\[is_primary\]"/)
  end

  it "moves the main sector to the newly starred one" do
    old_main = create(:sectorable_item, sectorable: person, sector: arts, is_primary: true)
    other = create(:sectorable_item, sectorable: person, sector: health)

    save_details(sectorable_items_attributes: {
      "0" => { id: old_main.id, sector_id: arts.id, _destroy: "0", is_primary: "0" },
      "1" => { id: other.id, sector_id: health.id, _destroy: "0", is_primary: "1" }
    })

    expect(person.reload.primary_sector).to eq(health)
  end

  it "rejects two main sectors" do
    save_details(sectorable_items_attributes: {
      "0" => { sector_id: arts.id, _destroy: "0", is_primary: "1" },
      "1" => { sector_id: health.id, _destroy: "0", is_primary: "1" }
    })

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Only one sector can be marked as primary")
  end

  describe "the email card" do
    it "shows each email with its type and a link to request a change" do
      person.update!(email_2: "second@example.com", email_2_type: "personal")

      get details_person_path(person)

      expect(response.body).to include(owner_user.email, "second@example.com")
      expect(response.body).to include("person[email_type]", "person[email_2_type]")
      expect(response.body).to include("field=primary_email&amp;person_id=#{person.id}&amp;return_to=details")
      expect(response.body).to include("field=secondary_email&amp;person_id=#{person.id}&amp;return_to=details")
      expect(response.body).not_to include("person[email]", "person[email_2]\"")
      expect(response.body).to match(/<a[^>]*target="_blank"[^>]*href="[^"]*field=secondary_email/)
    end

    it "offers to add a secondary email when there isn't one" do
      get details_person_path(person)

      expect(response.body).to include("Add a secondary email")
      expect(response.body).not_to include("person[email_2_type]")
    end

    it "saves both email types" do
      person.update!(email_2: "second@example.com")

      save_details(email_type: "work", email_2_type: "personal")

      expect(person.reload).to have_attributes(email_type: "work", email_2_type: "personal")
    end

    it "shows a pending email request" do
      create(:profile_change_request, :secondary_email, person: person, requested_by: owner_user, requested_value: "new2@example.com")

      get details_person_path(person)

      expect(response.body).to include("See your request", "Change to new2@example.com requested")
    end

    it "opens the request form on the chosen email and comes back to the card" do
      person.update!(email_2: "second@example.com")

      get new_profile_change_request_path(person_id: person, field: "secondary_email", return_to: "details")
      expect(response.body).to include("Current secondary email", "second@example.com", "Back to editing my profile")

      post profile_change_requests_path(person_id: person), params: {
        return_to: "details", profile_change_request: { field: "secondary_email", requested_value: "new2@example.com" }
      }
      expect(response).to redirect_to(details_person_path(person, anchor: "emails"))
    end
  end

  describe "phones" do
    it "offers a main-phone star, starring the first phone when none is main" do
      create(:contact_method, contactable: person, value: "555-0100")

      get details_person_path(person)

      expect(response.body).to include("Add another phone", "Make this my main phone", "Mark as main")
      expect(response.body).to match(/<input[^>]*checked="checked"[^>]*name="person\[contact_methods_attributes\]\[0\]\[primary\]"/)
      expect(response.body).to include("person[contact_methods_attributes][999][value]")
    end

    it "adds a second phone and moves the main flag to it" do
      first = create(:contact_method, contactable: person, value: "555-0100", primary: true)

      save_details(contact_methods_attributes: {
        "0" => { id: first.id, kind: "phone", value: "555-0100", primary: "0" },
        "999" => { kind: "phone", value: "555-0199", primary: "1" }
      })

      expect(person.reload.contact_methods.find_by(primary: true).value).to eq("555-0199")
      expect(person.contact_methods.count).to eq(2)
    end
  end

  describe "addresses" do
    it "offers a main-address star and a way to add another address" do
      create(:address, addressable: person, locality: "LA City", primary: true)

      get details_person_path(person)

      expect(response.body).to include("Add another address", "Make this my main address", "Mark as main")
      expect(response.body).to include("person[addresses_attributes][999][street_address]")
      expect(response.body).to match(/<input[^>]*checked="checked"[^>]*name="person\[addresses_attributes\]\[0\]\[primary\]"/)
    end

    it "stars a person's first address as main" do
      get details_person_path(person)

      expect(response.body).to match(/<input[^>]*checked="checked"[^>]*name="person\[addresses_attributes\]\[0\]\[primary\]"/)
    end

    it "adds a second address and moves the main flag to it" do
      home = create(:address, addressable: person, locality: "LA City", primary: true)

      save_details(addresses_attributes: {
        "0" => { id: home.id, street_address: home.street_address, city: home.city, state: home.state, locality: home.locality, primary: "0" },
        "999" => { street_address: "2 Oak Ave", city: "Pasadena", state: "CA", zip_code: "91101", locality: "LA County", primary: "1" }
      })

      expect(person.reload.addresses.find_by(primary: true).street_address).to eq("2 Oak Ave")
      expect(person.addresses.count).to eq(2)
    end
  end

  it "saves the time zone and best time to call" do
    save_details(best_time_to_call: "Weekday mornings", user_attributes: { id: owner_user.id, time_zone: "Eastern Time (US & Canada)" })

    expect(person.reload.best_time_to_call).to eq("Weekday mornings")
    expect(owner_user.reload.time_zone).to eq("Eastern Time (US & Canada)")
  end

  it "saves program settings without dropping age ranges" do
    settings_type = create(:category_type, :published, name: "WorkshopSetting", profile_specific: true)
    setting = create(:category, :published, category_type: settings_type, name: "Shelter")
    age_type = create(:category_type, :published, name: "AgeRange")
    teens = create(:category, :published, category_type: age_type, name: "Teens (13-17)")
    create(:categorizable_item, categorizable: person, category: teens)

    get details_person_path(person)
    expect(response.body).to include("Shelter")

    save_details(category_ids: [ "", setting.id.to_s ], managed_category_type_ids: [ "", settings_type.id.to_s ])

    expect(person.reload.categories).to contain_exactly(setting, teens)
  end

  it "adds a license from the add row" do
    save_details(professional_licenses_attributes: { "999" => { kind: "LMFT", number: "12345", issuing_state: "CA", expires_on: "2027-01-31" } })

    expect(person.reload.professional_licenses.map(&:number)).to eq([ "12345" ])
  end

  it "shows a license with CE credits as read-only" do
    license = create(:professional_license, person: person, number: "LOCK-1")
    allow_any_instance_of(ProfessionalLicense).to receive(:used_for_ce?).and_return(true)

    get details_person_path(person)

    expect(response.body).to include("LOCK-1", "only AWBW staff can change it")
    expect(response.body).not_to include(%(value="#{license.id}"))
  end

  it "re-renders the page when the save fails" do
    save_details(first_name: "")

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Edit my profile", "Sectors you work in")
  end

  it "logs field and sector changes to the person's change log as the owner" do
    events = buffered_during_request do
      save_details(first_name: "Jordan", sectorable_items_attributes: { "1" => { sector_id: health.id, _destroy: "0" } })
    end

    event = events.find { |e| e[:name] == "update.person" }
    expect(event).to be_present
    expect(event[:user]).to eq(owner_user)
    expect(event.dig(:properties, :changes, "first_name")).to include(after: "Jordan")
    expect(event.dig(:properties, :association_changes)).to be_present
  end

  it "is closed to other people" do
    sign_in create(:user)

    get details_person_path(person)

    expect(response).to redirect_to(root_path)
  end

  it "is closed in production" do
    allow(Rails.env).to receive(:production?).and_return(true)

    get details_person_path(person)

    expect(response).to redirect_to(root_path)
  end
end
