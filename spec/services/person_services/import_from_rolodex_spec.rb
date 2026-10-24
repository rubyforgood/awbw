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
                                      pronouns: "she/her", date_of_birth: Date.new(1815, 12, 10), notes: nil)
    expect(person.comments).to be_empty
    expect(person.addresses.sole).to have_attributes(street_address: "1 Main St, Apt 2", city: "Los Angeles", state: "CA",
                                                     zip_code: "90001", address_type: "personal", locality: "LA City", primary: true)
    expect(person.contact_methods.sole).to have_attributes(kind: "phone", value: "555-0100", contact_type: "work", primary: true)
  end

  it "splits two emails in one field into email and email_2" do
    rolodex("00007", EMail: "ada@example.com; ada@work.example.com")

    results

    expect(Person.find_by!(filemaker_code: "00007")).to have_attributes(email: "ada@example.com", email_2: "ada@work.example.com")
  end

  describe "an email the portal can't take" do
    it "creates the person without it and leaves the archive's value as a comment" do
      rolodex("00046", EMail: "Attn: ada@@example.com")

      import = described_class.new.call

      expect(import.results[:created].size).to eq(1)
      expect(import.results[:failed]).to be_empty
      person = Person.find_by!(filemaker_code: "00046")
      expect(person).to have_attributes(email: nil, email_2: nil)
      expect(person.comments.sole.body).to include("00046", "Attn: ada@@example.com")
      expect(import.invalid_emails.sole).to include("00046", "##{person.id}", "Attn: ada@@example.com")
    end

    it "notes a value with no address in it at all" do
      rolodex("00051", EmailPrimary: "ada at example dot com")

      results

      person = Person.find_by!(filemaker_code: "00051")
      expect(person).to have_attributes(email: nil, email_2: nil)
      expect(person.comments.sole.body).to include("ada at example dot com")
    end

    it "keeps the row's usable address as the person's email without a comment" do
      rolodex("00047", EmailPrimary: "ada@example.com.", EMail: "ada@work.example.com")

      import = described_class.new.call

      person = Person.find_by!(filemaker_code: "00047")
      expect(person).to have_attributes(email: "ada@work.example.com", email_2: nil)
      expect(person.comments).to be_empty
      expect(import.invalid_emails).to be_empty
    end

    it "leaves a linked person's second email unfilled and uncommented" do
      person = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com")
      rolodex("00048", EmailPrimary: "ada@example.com", EMail: "ada@old@example.com")

      expect { expect(results[:linked].size).to eq(1) }.not_to change(Person, :count)
      expect(person.reload).to have_attributes(filemaker_code: "00048", email: "ada@example.com", email_2: nil)
      expect(person.comments).to be_empty
    end

    it "creates a new person with a placeholder email rather than linking a same-name one" do
      existing = create(:person, first_name: "Ada", last_name: "Lovelace", email: nil, user: nil)
      rolodex("00049", EMail: "ada@@example.com")
      rolodex("00050", EMail: "ada at example dot com")

      import = described_class.new.call

      expect(import.results[:created].size).to eq(2)
      expect(import.results[:linked]).to be_empty
      expect(existing.reload.filemaker_code).to be_nil
      expect(Person.where(filemaker_code: %w[00049 00050]).order(:filemaker_code).pluck(:email))
        .to eq([ PlaceholderEmail.at(1), PlaceholderEmail.at(2) ])
      expect(Person.find_by!(filemaker_code: "00050").comments.sole.body).to include("ada at example dot com")
    end

    it "relinks the person it created when the row is named again" do
      rolodex("00052", EMail: "ada@@example.com")

      described_class.new.call
      import = described_class.new(scope: FmRolodex.where(fm_id: "00052"), relink: true).call

      expect(import.results[:linked].size).to eq(1)
      expect(Person.sole.comments.count).to eq(1)
    end
  end

  describe "the fields FmRolodex::PORTAL_FIELDS maps onto a person" do
    let!(:age_range_type) { create(:category_type, name: "AgeRange", published: true) }
    let!(:children) { create(:category, :published, category_type: age_range_type, name: "Children") }
    let!(:teens) { create(:category, :published, category_type: age_range_type, name: "Teens") }
    let!(:adults) { create(:category, :published, category_type: age_range_type, name: "Adults") }
    let!(:elders) { create(:category, :published, category_type: age_range_type, name: "Elders") }
    let!(:domestic_violence) { create(:sector, :published, name: "Domestic Violence") }
    let!(:child_abuse) { create(:sector, :published, name: "Child Abuse/Neglect") }
    let!(:education) { create(:sector, :published, name: "Education") }
    let!(:mental_health) { create(:sector, :published, name: "Mental Health") }
    let!(:grief) { create(:sector, :published, name: "Grief/Loss") }

    before do
      create(:tag_alias, name: "Child Abuse", aliasable: child_abuse)
      create(:tag_alias, name: "Student Services", aliasable: education)
      create(:tag_alias, name: "Clinical Setting", aliasable: mental_health)
      create(:tag_alias, name: "Virtually", aliasable: nil, ignored: true)
      create(:tag_alias, name: "Children's Services", aliasable: children)
      create(:tag_alias, name: "Elder Abuse", aliasable: elders)
      [ children, teens, adults, elders ].each { |age| create(:tag_alias, name: "Families", aliasable: age) }
    end

    it "carries the email type, facilitator start, service areas, age group, and entry date" do
      rolodex("00050", EMail: "ada@example.com", EmailType: "Work", FacilitatorSinceMonth: "3",
                       FacilitatorSinceYear: "2011", PrimaryServiceArea: "Domestic Violence",
                       OtherServiceArea: "Child Abuse; Homelessness", PrimaryAgeGroup: "Adults",
                       DateEntered: "03/14/2011", DateTimeModified: "09/02/2014 10:22:31")

      import = described_class.new.call
      person = Person.find_by!(filemaker_code: "00050")

      expect(person).to have_attributes(email_type: "work", member_since: Date.new(2011, 3, 1))
      expect(person.created_at.to_date).to eq(Date.new(2011, 3, 14))
      expect(person.updated_at.to_date).to eq(Date.new(2014, 9, 2))
      expect(person.primary_sector).to eq(domestic_violence)
      expect(person.sectorable_items.map(&:sector)).to contain_exactly(domestic_violence, child_abuse)
      expect(person.primary_age_groups).to eq([ adults ])
      expect(import.unmatched_tags).to eq({ "homelessness" => 1 })
    end

    it "resolves legacy words through the recorded translations" do
      rolodex("00054", EMail: "ada@example.com", PrimaryServiceArea: "Student Services")

      described_class.new.call

      expect(Person.find_by!(filemaker_code: "00054").primary_sector).to eq(education)
    end

    it "adds the settings and life experiences as additional sectors" do
      rolodex("00055", EMail: "ada@example.com", PrimaryServiceArea: "Domestic Violence",
                       Settings: "Clinical Setting\rVirtually", LifeExperiences: "Grief/Loss\rDomestic Violence")

      import = described_class.new.call
      person = Person.find_by!(filemaker_code: "00055")

      expect(person.primary_sector).to eq(domestic_violence)
      expect(person.sectorable_items.where(is_primary: false).map(&:sector)).to contain_exactly(mental_health, grief)
      expect(import.unmatched_tags).to be_empty
    end

    it "takes an age group a sector field names as primary or additional by the field it sat in" do
      rolodex("00056", EMail: "ada@example.com", PrimaryServiceArea: "Children's Services", LifeExperiences: "Elder Abuse")

      described_class.new.call
      person = Person.find_by!(filemaker_code: "00056")

      expect(person.primary_age_groups).to eq([ children ])
      expect(person.additional_age_groups).to eq([ elders ])
      expect(person.sectorable_items).to be_empty
    end

    it "lands every sector a primary answer names as additional when it names several" do
      homelessness = create(:sector, :published, name: "Homelessness")
      create(:tag_alias, name: "Domestic Violence & Homelessness", aliasable: domestic_violence)
      create(:tag_alias, name: "Domestic Violence & Homelessness", aliasable: homelessness)
      rolodex("00058", EMail: "ada@example.com", PrimaryServiceArea: "Domestic Violence & Homelessness")

      described_class.new.call
      person = Person.find_by!(filemaker_code: "00058")

      expect(person.primary_sector).to be_nil
      expect(person.sectorable_items.where(is_primary: false).map(&:sector)).to contain_exactly(domestic_violence, homelessness)
    end

    it "adds a linked person's tags without replacing the primary they already have" do
      person = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com")
      person.tag_sectors(primary_ids: [ education.id ], additional_ids: [])
      rolodex("00059", EMail: "ada@example.com", PrimaryServiceArea: "Domestic Violence", PrimaryAgeGroup: "Adults")

      import = described_class.new.call
      person.reload

      expect(person.primary_sector).to eq(education)
      expect(person.sectorable_items.where(is_primary: false).map(&:sector)).to eq([ domestic_violence ])
      expect(person.primary_age_groups).to eq([ adults ])
      expect(import.differences.sole).to include("Primary sector", "Domestic Violence", "Education")
    end

    it "leaves a primary the archive names too as the person's primary" do
      person = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com")
      person.tag_sectors(primary_ids: [ domestic_violence.id ], additional_ids: [])
      person.tag_age_groups(primary_ids: [ adults.id ], additional_ids: [])
      rolodex("00061", EMail: "ada@example.com", PrimaryServiceArea: "Domestic Violence",
                       PrimaryAgeGroup: "Adults", LifeExperiences: "Domestic Violence")

      import = described_class.new.call
      person.reload

      expect(person.primary_sector).to eq(domestic_violence)
      expect(person.primary_age_groups).to eq([ adults ])
      expect(person.additional_age_groups).to be_empty
      expect(import.differences).to be_empty
    end

    it "takes the one primary age group from the field that names it" do
      rolodex("00062", EMail: "ada@example.com", PrimaryServiceArea: "Children's Services", PrimaryAgeGroup: "Adults")

      described_class.new.call
      person = Person.find_by!(filemaker_code: "00062")

      expect(person.primary_age_groups).to eq([ adults ])
      expect(person.additional_age_groups).to eq([ children ])
    end

    it "takes the primary age group a sector field names when the age group field has none to give" do
      rolodex("00063", EMail: "ada@example.com", PrimaryServiceArea: "Children's Services", PrimaryAgeGroup: "Families")

      described_class.new.call
      person = Person.find_by!(filemaker_code: "00063")

      expect(person.primary_age_groups).to eq([ children ])
      expect(person.additional_age_groups).to contain_exactly(teens, adults, elders)
    end

    it "tags every age range for families without marking one primary" do
      rolodex("00057", EMail: "ada@example.com", PrimaryAgeGroup: "Families")

      described_class.new.call
      person = Person.find_by!(filemaker_code: "00057")

      expect(person.primary_age_groups).to be_empty
      expect(person.additional_age_groups).to contain_exactly(children, teens, adults, elders)
      expect(person).to be_valid
    end

    it "reads the archive's email types, placing a kind it can't and leaving a precedence word untyped" do
      { "00090" => "Business", "00091" => "Professional", "00092" => "Preferred", "00093" => "Attn: someone", "00094" => "" }
        .each_with_index { |(fm_id, type), i| rolodex(fm_id, FirstName: "Ada#{i}", EMail: "ada#{i}@example.com", EmailType: type) }

      described_class.new.call

      # "Preferred" says which address to use, which its own slot already says — not a kind.
      expect(Person.where(filemaker_code: %w[00090 00091 00092 00093 00094]).order(:filemaker_code).pluck(:email_type))
        .to eq([ "work", "work", nil, "unknown", nil ])
    end

    it "reads a facilitator year with no month as January, and a month name" do
      rolodex("00051", FirstName: "Grace", EMail: "grace@example.com", FacilitatorSinceYear: "2018")
      rolodex("00052", FirstName: "Hedy", EMail: "hedy@example.com", FacilitatorSinceMonth: "June",
                       FacilitatorSinceYear: "2014")

      results

      expect(Person.find_by!(filemaker_code: "00051").member_since).to eq(Date.new(2018, 1, 1))
      expect(Person.find_by!(filemaker_code: "00052").member_since).to eq(Date.new(2014, 6, 1))
    end

    it "leaves the fields alone when the archive row doesn't carry them" do
      rolodex("00053", EMail: "ada@example.com")

      import = described_class.new.call
      person = Person.find_by!(filemaker_code: "00053")

      expect(person).to have_attributes(email_type: nil, member_since: nil)
      expect(person.sectorable_items).to be_empty
      expect(person.categorizable_items).to be_empty
      expect(person.created_at).to be_within(1.minute).of(Time.current)
      expect(import.unmatched_tags).to be_empty
    end
  end

  it "reads an address's county from the archive's zip code table" do
    FmPostalCode.create!(fm_id: "90013", data: { "City" => "Los Angeles", "State" => "CA", "County" => "Los Angeles" })
    FmPostalCode.create!(fm_id: "02139", data: { "City" => "Cambridge", "State" => "MA", "County" => "Middlesex" })
    FmAddress.create!(fm_id: "A7", data: { "AddrsLine1" => "1 Main St", "AddrsCity" => "Los Angeles", "AddrsState" => "CA",
                                           "PostalCodeLookup" => "90013", "AddrsPostalCode" => "90013" })
    FmAddress.create!(fm_id: "A8", data: { "AddrsLine1" => "2 Mass Ave", "AddrsCity" => "Cambridge", "AddrsState" => "MA",
                                           "AddrsPostalCode" => "02139-4307" })
    FmAddress.create!(fm_id: "A9", data: { "AddrsLine1" => "3 Elm St", "AddrsCity" => "Nowhere", "AddrsState" => "CA",
                                           "AddrsPostalCode" => "99999" })
    rolodex("00036", EMail: "ada@example.com", PrimaryAddrsID: "A7")
    rolodex("00037", FirstName: "Grace", EMail: "grace@example.com", PrimaryAddrsID: "A8")
    rolodex("00038", FirstName: "Hedy", EMail: "hedy@example.com", PrimaryAddrsID: "A9")

    results

    expect(%w[00036 00037 00038].map { |code| Person.find_by!(filemaker_code: code).addresses.sole.county })
      .to eq([ "Los Angeles", "Middlesex", nil ])
  end

  it "takes the ZIP an address only points at in the archive's ZIP table" do
    FmPostalCode.create!(fm_id: "94110", data: { "City" => "San Francisco", "State" => "CA", "County" => "San Francisco" })
    FmAddress.create!(fm_id: "A11", data: { "AddrsLine1" => "1 Main St", "AddrsCity" => "San Francisco",
                                            "AddrsState" => "CA", "PostalCodeLookup" => "94110" })
    rolodex("00046", EMail: "ada@example.com", PrimaryAddrsID: "A11")

    results

    expect(Person.find_by!(filemaker_code: "00046").addresses.sole)
      .to have_attributes(zip_code: "94110", county: "San Francisco")
  end

  it "reads an address's locality from its own parts, since the archive records none for a person" do
    FmPostalCode.create!(fm_id: "91101", data: { "County" => "Los Angeles" })
    FmAddress.create!(fm_id: "A12", data: { "AddrsLine1" => "1 Colorado Blvd", "AddrsCity" => "Pasadena",
                                            "AddrsState" => "CA", "AddrsPostalCode" => "91101" })
    FmAddress.create!(fm_id: "A13", data: { "AddrsLine1" => "2 Mass Ave", "AddrsCity" => "Cambridge", "AddrsState" => "MA" })
    FmAddress.create!(fm_id: "A14", data: { "AddrsLine1" => "3 Queen St", "AddrsCity" => "Toronto",
                                            "AddrsState" => "ON", "AddrsCountry" => "Canada" })
    rolodex("00047", EMail: "ada@example.com", PrimaryAddrsID: "A12")
    rolodex("00048", FirstName: "Grace", EMail: "grace@example.com", PrimaryAddrsID: "A13")
    rolodex("00049", FirstName: "Hedy", EMail: "hedy@example.com", PrimaryAddrsID: "A14")

    results

    expect(%w[00047 00048 00049].map { |code| Person.find_by!(filemaker_code: code).addresses.sole.locality })
      .to eq([ "LA County", "Outside CA", "Outside USA" ])
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

  it "brings in every address and phone the row answers to, primary first" do
    FmAddress.create!(fm_id: "A20", data: { "RolodexID" => "00060", "AddrsLine1" => "2 Second St",
                                            "AddrsCity" => "Oakland", "AddrsState" => "CA" })
    FmAddress.create!(fm_id: "A21", data: { "AddrsLine1" => "1 Main St", "AddrsCity" => "Los Angeles",
                                            "AddrsState" => "CA" })
    FmPhoneNumber.create!(fm_id: "P20", data: { "RolodexID" => "00060", "PhoneNumber" => "555-0200" })
    FmPhoneNumber.create!(fm_id: "P21", data: { "PhoneNumber" => "555-0100" })
    rolodex("00060", EMail: "ada@example.com", PrimaryAddrsID: "A21", PrimaryPhoneID: "P21")

    results

    person = Person.find_by!(filemaker_code: "00060")
    expect(person.addresses.order(:id).pluck(:street_address, :primary))
      .to eq([ [ "1 Main St", true ], [ "2 Second St", false ] ])
    expect(person.contact_methods.order(:id).pluck(:value, :primary))
      .to eq([ [ "555-0100", true ], [ "555-0200", false ] ])
  end

  it "reads the address and phone tables once, not once per row" do
    3.times do |i|
      FmAddress.create!(fm_id: "A8#{i}", data: { "RolodexID" => "0008#{i}", "AddrsLine1" => "#{i} Main St",
                                                "AddrsCity" => "Los Angeles", "AddrsState" => "CA" })
      FmPhoneNumber.create!(fm_id: "P8#{i}", data: { "RolodexID" => "0008#{i}", "PhoneNumber" => "555-010#{i}" })
      rolodex("0008#{i}", FirstName: "Ada#{i}", EMail: "ada#{i}@example.com")
    end
    queries = []
    counter = ->(*, payload) { queries << payload[:sql] if payload[:sql].match?(/FROM `fm_(addresses|phone_numbers)`/) }

    ActiveSupport::Notifications.subscribed(counter, "sql.active_record") { results }

    expect(queries.size).to eq(2)
    expect(Person.find_by!(filemaker_code: "00082").addresses.sole.street_address).to eq("2 Main St")
  end

  it "leaves a work address off the person, for the affiliations import to bring in" do
    FmAddress.create!(fm_id: "A90", data: { "RolodexID" => "00095", "AddrsLine1" => "1 Home St",
                                            "AddrsCity" => "Los Angeles", "AddrsState" => "CA" })
    FmAddress.create!(fm_id: "A91", data: { "AddrsLine1" => "2 Worksite St", "AddrsCity" => "Oakland", "AddrsState" => "CA" })
    FmAddress.create!(fm_id: "A92", data: { "RolodexID" => "00095", "AddrsLine1" => "3 Office St", "AddrsCity" => "Oakland",
                                            "AddrsState" => "CA", "AddrsType" => "Work" })
    rolodex("00095", EMail: "ada@example.com", WorksiteAddrsID: "A91")

    results

    expect(Person.find_by!(filemaker_code: "00095").addresses.pluck(:street_address, :primary)).to eq([ [ "1 Home St", true ] ])
  end

  describe "the activity it logs" do
    around do |example|
      Current.source = "fm_import_people"
      example.run
    ensure
      Current.reset
    end

    def run_events(run) = Ahoy::Event.where("JSON_UNQUOTE(JSON_EXTRACT(properties, '$.import_run')) = ?", run)

    it "tags every record it creates or fills with the run" do
      linked = create(:person, first_name: "Grace", last_name: "Hopper", email: "grace@example.com")
      rolodex("00110", EMail: "ada@example.com")
      rolodex("00111", FirstName: "Grace", LastName: "Hopper", EMail: "grace@example.com", Pronouns: "she/her")

      described_class.new(run: "run-1").call
      created = Person.find_by!(filemaker_code: "00110")

      expect(run_events("run-1").where(name: "create.person").map { |event| event.properties["resource_id"] }).to eq([ created.id ])
      fill = run_events("run-1").find_by!(name: "update.person")
      expect(fill.properties).to include("resource_id" => linked.id)
      expect(fill.properties["changes"]).to include("pronouns" => { "before" => nil, "after" => "she/her" })
    end
  end

  describe "batches" do
    before { stub_const("#{described_class}::BATCH_SIZE", 1) }

    it "keeps the batches it finished and rolls back the one that fails" do
      stub_const("#{described_class}::BATCH_SIZE", 2)
      rolodex("00101", EMail: "ada@example.com")
      rolodex("00102", FirstName: "Grace", EMail: "grace@example.com")
      rolodex("00105", FirstName: "Hedy", EMail: "hedy@example.com")
      rolodex("00106", FirstName: "Mary", EMail: "mary@example.com")
      allow_any_instance_of(described_class).to receive(:import).and_wrap_original do |original, rolodex|
        raise "stopped" if rolodex.fm_id == "00106"

        original.call(rolodex)
      end

      expect { described_class.new.call }.to raise_error("stopped")
      expect(Person.where(filemaker_code: %w[00101 00102 00105]).pluck(:filemaker_code)).to contain_exactly("00101", "00102")
    end

    it "reports how many rows it has read after each batch" do
      rolodex("00103", EMail: "ada@example.com")
      rolodex("00104", FirstName: "Grace", EMail: "grace@example.com")
      read = []

      described_class.new(progress: ->(count) { read << count }).call

      expect(read).to eq([ 1, 2 ])
    end
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

  it "truncates an over-long city, state, and postal code instead of losing the address" do
    FmAddress.create!(fm_id: "A10", data: { "AddrsLine1" => "1 Main St", "AddrsCity" => "c" * 300,
                                            "AddrsState" => "s" * 300, "AddrsPostalCode" => "9" * 300 })
    rolodex("00039", EMail: "ada@example.com", PrimaryAddrsID: "A10")

    expect(results[:failed]).to be_empty

    address = Person.find_by!(filemaker_code: "00039").addresses.sole
    expect([ address.city.length, address.state.length, address.zip_code.length ]).to eq([ 255, 255, 255 ])
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

  describe "the staff the archive stamped on a row" do
    let!(:entered_by) { create(:user) }
    let!(:modified_by) { create(:user) }
    let!(:awbw_staff) { create(:user).tap { |user| Setting.create!(import_user: user) } }

    before do
      create(:staff_alias, name: "Dana Whitfield", user: entered_by)
      create(:staff_alias, name: "noor!", user: modified_by)
      create(:staff_alias, :ignored, name: "Staff")
    end

    it "stamps a created person with the portal users the archive's names mean" do
      rolodex("00100", EMail: "ada@example.com", EnteredBy: "Dana Whitfield", ModifiedBy: "noor!")

      import = described_class.new.call

      expect(Person.find_by!(filemaker_code: "00100"))
        .to have_attributes(created_by_id: entered_by.id, updated_by_id: modified_by.id)
      expect(import.unmatched_staff).to be_empty
    end

    it "credits the settings' import user for a name no portal user answers to, and reports it" do
      rolodex("00101", EMail: "ada@example.com", EnteredBy: "Marisol Trevino", ModifiedBy: "Staff")
      rolodex("00103", FirstName: "Grace", EMail: "grace@example.com")

      import = described_class.new.call

      expect(Person.where(filemaker_code: %w[00101 00103]).pluck(:created_by_id, :updated_by_id).flatten.uniq)
        .to eq([ awbw_staff.id ])
      # The shared login names no one on purpose, so only the undecided name is reported.
      expect(import.unmatched_staff).to eq({ "Marisol Trevino" => 1 })
    end

    it "fills a linked person's empty stamps and keeps the ones they have" do
      blank = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com")
      blank.update_columns(created_by_id: nil, updated_by_id: nil)
      stamped = create(:person, first_name: "Grace", last_name: "Hopper", email: "grace@example.com")
      stamped.update_columns(created_by_id: modified_by.id, updated_by_id: modified_by.id)
      rolodex("00102", EMail: "ada@example.com", EnteredBy: "Dana Whitfield", ModifiedBy: "Staff")
      rolodex("00104", FirstName: "Grace", LastName: "Hopper", EMail: "grace@example.com", EnteredBy: "Dana Whitfield")

      described_class.new.call

      expect(blank.reload).to have_attributes(created_by_id: entered_by.id, updated_by_id: awbw_staff.id)
      expect(stamped.reload).to have_attributes(created_by_id: modified_by.id, updated_by_id: modified_by.id)
    end
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

  describe "filling a linked person from the archive" do
    let!(:person) { create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", pronouns: "she/her") }

    it "fills the fields the person has blank" do
      rolodex("00070", EMail: "ada@example.com; ada@work.example.com", DateOfBirth: "12/10/1815",
                       BestTimeToCall: "Mornings", Comments: "Met at training")

      described_class.new.call

      expect(person.reload).to have_attributes(date_of_birth: Date.new(1815, 12, 10), best_time_to_call: "Mornings",
                                               notes: nil, email_2: "ada@work.example.com")
      expect(person.comments).to be_empty
    end

    it "doesn't note a field it only filled in" do
      rolodex("00075", EMail: "ada@example.com", BestTimeToCall: "Mornings")

      import = described_class.new.call

      expect(person.reload.best_time_to_call).to eq("Mornings")
      expect(person.comments).to be_empty
      expect(import.differences).to be_empty
    end

    it "keeps the person's value where the archive differs and notes the difference" do
      rolodex("00071", EMail: "ada@example.com", Pronouns: "they/them")

      import = described_class.new.call

      expect(person.reload.pronouns).to eq("she/her")
      expect(person.comments.sole.body).to include("00071", "Pronouns", "they/them", "she/her")
      expect(import.differences.sole).to include("00071", "##{person.id}", "Pronouns", "they/them", "she/her")
    end

    it "doesn't note an archive email type it could only read as unknown" do
      person.update!(email_type: "work")
      rolodex("00074", EMail: "ada@example.com", EmailType: "Attn: someone")

      import = described_class.new.call

      expect(person.reload.email_type).to eq("work")
      expect(import.differences).to be_empty
    end

    it "doesn't note a value that only differs in case or spacing" do
      rolodex("00072", EMail: "ada@example.com", Pronouns: " She/Her ")

      import = described_class.new.call

      expect(person.comments).to be_empty
      expect(import.differences).to be_empty
    end

    it "adds the archive's addresses and phones the person doesn't have, keeping their primary" do
      create(:address, addressable: person, street_address: "1 Main St", city: "Los Angeles", state: "CA", primary: true)
      FmAddress.create!(fm_id: "A70", data: { "AddrsLine1" => "1 Main Street", "AddrsCity" => "Los Angeles", "AddrsState" => "CA" })
      FmAddress.create!(fm_id: "A71", data: { "RolodexID" => "00073", "AddrsLine1" => "2 Second St",
                                              "AddrsCity" => "Oakland", "AddrsState" => "CA" })
      FmPhoneNumber.create!(fm_id: "P70", data: { "PhoneNumber" => "555-0100" })
      rolodex("00073", EMail: "ada@example.com", PrimaryAddrsID: "A70", PrimaryPhoneID: "P70")

      described_class.new.call

      expect(person.addresses.order(:id).pluck(:street_address, :primary))
        .to eq([ [ "1 Main St", true ], [ "2 Second St", false ] ])
      expect(person.contact_methods.pluck(:value, :primary)).to eq([ [ "555-0100", true ] ])
    end
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

  it "takes the primary email field as the person's email, the other field's as their second" do
    rolodex("00041", EmailPrimary: "ada@example.com", EMail: "ada@work.example.com")
    rolodex("00042", FirstName: "Grace", EmailPrimary: "grace@example.com", EMail: "grace@example.com")
    rolodex("00043", FirstName: "Hedy", EMail: "hedy@example.com")

    results

    expect(Person.find_by!(filemaker_code: "00041"))
      .to have_attributes(email: "ada@example.com", email_2: "ada@work.example.com")
    expect(Person.find_by!(filemaker_code: "00042")).to have_attributes(email: "grace@example.com", email_2: nil)
    expect(Person.find_by!(filemaker_code: "00043")).to have_attributes(email: "hedy@example.com", email_2: nil)
  end

  it "links a person the archive knows only by its primary email field" do
    person = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com")
    rolodex("00044", EmailPrimary: "ada@example.com")

    expect { expect(results[:linked].size).to eq(1) }.not_to change(Person, :count)
    expect(person.reload.filemaker_code).to eq("00044")
  end

  it "links a person only the row's other email field reaches" do
    person = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com")
    rolodex("00045", EmailPrimary: "ada@old.example.com", EMail: "ada@example.com")

    expect { expect(results[:linked].size).to eq(1) }.not_to change(Person, :count)
    expect(person.reload).to have_attributes(filemaker_code: "00045", email_2: "ada@old.example.com")
  end

  it "leaves rows whose ID a person already carries alone" do
    create(:person, filemaker_code: "00009")
    rolodex("00009")

    expect(results[:already_imported].size).to eq(1)
    expect(Person.where(filemaker_code: "00009").count).to eq(1)
  end

  it "creates a new person when the email belongs to a differently named one" do
    babbage = create(:person, first_name: "Charles", last_name: "Babbage", email: "ada@example.com")
    rolodex("00010", EMail: "ada@example.com")

    expect { expect(results[:created].size).to eq(1) }.to change(Person, :count).by(1)
    expect(Person.find_by!(filemaker_code: "00010")).to have_attributes(first_name: "Ada", email: "ada@example.com")
    expect(babbage.reload.filemaker_code).to be_nil
  end

  it "links a same-name person with no email" do
    # A linked login would become their primary email (PersonLoginEmailSync), so the
    # person this reaches is one with no account.
    person = create(:person, first_name: "Ada", last_name: "Lovelace", email: nil, user: nil)
    rolodex("00011")

    expect { expect(results[:linked].size).to eq(1) }.not_to change(Person, :count)
    expect(person.reload.filemaker_code).to eq("00011")
  end

  it "adds the row's ID to a match already linked to another FileMaker record" do
    person = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", filemaker_code: "99999")
    rolodex("00012", EMail: "ada@example.com")

    expect(results[:linked].size).to eq(1)
    expect(person.reload.filemaker_codes).to eq(%w[00012 99999])
  end

  it "adds the row's ID to every person the name and email answer to" do
    first = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com")
    second = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada.l@example.com", email_2: "ada@example.com")
    rolodex("00018", EMail: "ada@example.com")

    expect { expect(results[:linked].size).to eq(1) }.not_to change(Person, :count)
    expect([ first, second ].map { |person| person.reload.filemaker_code }).to eq(%w[00018 00018])
  end

  it "counts a match with two logins once" do
    person = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com", pronouns: "she/her")
    # Attached without the login sync, which would make the second account's email the person's own.
    create(:user).update_columns(person_id: person.id)
    rolodex("00019", EMail: "ada@example.com", Pronouns: "they/them")

    import = described_class.new.call

    expect(import.results[:linked].sole).to eq("00019 Ada Lovelace → ##{person.id}")
    expect(person.comments.count).to eq(1)
  end

  it "links the row's other matches when one of them doesn't validate" do
    broken = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com")
    # A legacy value the email validation rejects, so every save of this person fails.
    broken.update_columns(email_2: "not-an-email")
    good = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada.l@example.com", email_2: "ada@example.com")
    rolodex("00024", EMail: "ada@example.com", BestTimeToCall: "Mornings")

    import = described_class.new.call

    expect(import.results[:failed].sole).to include("##{broken.id}", "valid email address")
    expect(import.results[:linked].sole).to eq("00024 Ada Lovelace → ##{good.id}")
    expect(good.reload).to have_attributes(filemaker_code: "00024", best_time_to_call: "Mornings")
    expect(broken.reload.filemaker_code).to be_nil
  end

  describe "re-running named rows" do
    it "links the match that failed, leaving the one that already carries the ID alone" do
      broken = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada@example.com")
      # A legacy value the email validation rejects, so the first run can't save this person.
      broken.update_columns(email_2: "not-an-email")
      good = create(:person, first_name: "Ada", last_name: "Lovelace", email: "ada.l@example.com",
                             email_2: "ada@example.com", pronouns: "she/her")
      rolodex("00025", EMail: "ada@example.com", Pronouns: "they/them", BestTimeToCall: "Mornings")

      described_class.new.call
      broken.update!(email_2: nil)
      import = described_class.new(scope: FmRolodex.where(fm_id: "00025"), relink: true).call

      expect(import.results[:linked].sole).to include("##{broken.id}", "##{good.id}")
      expect(broken.reload).to have_attributes(filemaker_code: "00025", best_time_to_call: "Mornings")
      expect(broken.comments).to be_empty
      expect(good.reload.comments.count).to eq(1)
      expect(import.differences).to be_empty
    end

    it "leaves the already-imported guard in place without it" do
      rolodex("00026", EMail: "ada@example.com")

      described_class.new.call

      expect(described_class.new(scope: FmRolodex.where(fm_id: "00026")).call.results[:already_imported].size).to eq(1)
    end
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
