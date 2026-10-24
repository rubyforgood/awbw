require "rails_helper"

RSpec.describe "People search", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:turbo_headers) { { "Turbo-Frame" => "people_results", "Accept" => "text/html" } }

  before { sign_in admin }

  describe "GET /people (turbo frame)" do
    let!(:person_alice) { create(:person, first_name: "Alice", last_name: "Wonderland") }
    let!(:person_bob)   { create(:person, first_name: "Bob", last_name: "Builder") }

    it "returns search results successfully" do
      get people_path, headers: turbo_headers
      expect(response).to have_http_status(:ok)
    end

    it "shows the admin-only phone filter" do
      get people_path
      expect(response.body).to include('name="phone"')
    end

    it "breaks the person profile button out of the results frame" do
      get people_path, headers: turbo_headers
      expect_frame_breakout(response.body, person_path(person_alice))
    end

    it "returns all people when no filters are applied" do
      get people_path, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).to include("Bob")
    end

    it "filters by contact_info" do
      get people_path, params: { contact_info: "Alice" }, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).not_to include("Bob")
    end

    it "filters by organization name" do
      org = create(:organization, name: "Unique Org")
      create(:affiliation, person: person_alice, organization: org)

      get people_path, params: { organization_name: "Unique Org" }, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).not_to include("Bob")
    end

    it "filters by role" do
      create(:story, author: person_alice)

      get people_path, params: { role: "story_author" }, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).not_to include("Bob")
    end

    it "filters by facilitator status" do
      create(:affiliation, person: person_alice, title: "Facilitator", end_date: nil)
      create(:affiliation, person: person_bob, title: "Facilitator", end_date: 1.year.ago)

      get people_path, params: { facilitator_status: "active" }, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).not_to include("Bob")
    end

    it "filters by topic subscription" do
      topic = create(:topic_subscription_type)
      create(:topic_subscription, person: person_bob, topic_subscription_type: topic)

      get people_path, params: { topic_subscription_type_id: topic.id }, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Bob")
      expect(response.body).not_to include("Alice")
    end

    it "filters by several topic subscriptions at once" do
      topic_a = create(:topic_subscription_type)
      topic_b = create(:topic_subscription_type)
      create(:topic_subscription, person: person_alice, topic_subscription_type: topic_a)
      create(:topic_subscription, person: person_bob, topic_subscription_type: topic_b)

      get people_path, params: { topic_subscription_type_id: [ topic_a.id, topic_b.id ] }, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).to include("Bob")
    end

    it "filters by staff tag" do
      tag = create(:staff_tag)
      create(:staff_tagging, staff_tag: tag, staff_taggable: person_alice)

      get people_path, params: { staff_tag_ids: tag.id }, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).not_to include("Bob")
    end

    it "filters by several staff tags at once" do
      tag_a = create(:staff_tag)
      tag_b = create(:staff_tag)
      create(:staff_tagging, staff_tag: tag_a, staff_taggable: person_alice)
      create(:staff_tagging, staff_tag: tag_b, staff_taggable: person_bob)

      get people_path, params: { staff_tag_ids: [ tag_a.id, tag_b.id ] }, headers: turbo_headers
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Alice")
      expect(response.body).to include("Bob")
    end
  end

  describe "GET /people (full page) admin filters" do
    it "always renders the staff tag filter with a manage link, even when none are published" do
      expect(StaffTag.published).to be_empty

      get people_path
      page = Capybara.string(response.body)
      expect(page).to have_css('select[name="staff_tag_ids[]"][multiple]')
      expect(page).to have_link("Manage staff tags", href: staff_tags_path)
    end

    it "always renders the topic subscription filter with a manage link, even when none exist" do
      expect(TopicSubscriptionType.active).to be_empty

      get people_path
      page = Capybara.string(response.body)
      expect(page).to have_css('select[name="topic_subscription_type_id[]"][multiple]')
      expect(page).to have_link("Manage topics", href: topic_subscription_types_path)
    end

    it "tells TomSelect what to show while nothing is selected" do
      get people_path
      page = Capybara.string(response.body)
      expect(page).to have_css('select[name="staff_tag_ids[]"][data-placeholder="Any"]')
      expect(page).to have_css('select[name="topic_subscription_type_id[]"][data-placeholder="Any topic"]')
    end
  end

  # The index opens to any signed-in user while profiles preview, but the filter
  # bar's admin-only controls must not be appliable by URL — they narrow the list
  # by internal data (PersonPolicy::ADMIN_ONLY_FILTERS).
  describe "GET /people (turbo frame) as a non-admin" do
    let(:viewer) { create(:user) }
    let(:tag) { create(:staff_tag) }
    let(:topic) { create(:topic_subscription_type) }

    def published_person(first_name)
      person = create(:person, first_name: first_name, last_name: "Facil", profile_is_searchable: true)
      create(:affiliation, person: person, title: "Facilitator", start_date: 1.year.ago, inactive: false)
      person
    end

    let!(:marked) { published_person("Markedone") }
    let!(:plain) { published_person("Plainone") }

    before do
      create(:staff_tagging, staff_tag: tag, staff_taggable: marked)
      create(:topic_subscription, person: marked, topic_subscription_type: topic)
      sign_in viewer
    end

    it "hides the admin-only filter controls" do
      get people_path
      expect(response.body).not_to include("Admin-only filters")
      expect(response.body).not_to include("staff_tag_ids")
      expect(response.body).not_to include('name="phone"')
    end

    it "ignores a staff tag filter passed by URL" do
      get people_path, params: { staff_tag_ids: [ tag.id ] }, headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Markedone")
      expect(response.body).to include("Plainone")
    end

    it "ignores a topic subscription filter passed by URL" do
      get people_path, params: { topic_subscription_type_id: [ topic.id ] }, headers: turbo_headers

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Markedone")
      expect(response.body).to include("Plainone")
    end

    it "still applies the filters the bar does offer them" do
      get people_path, params: { contact_info: "Markedone" }, headers: turbo_headers

      expect(response.body).to include("Markedone")
      expect(response.body).not_to include("Plainone")
    end

    describe "contact info search" do
      def search(term)
        get people_path, params: { contact_info: term }, headers: turbo_headers
        response.body
      end

      it "matches a shared email" do
        marked.update!(email: "marked@example.com", profile_show_email: true)
        expect(search("marked@example")).to include("Markedone")
      end

      it "skips an email the person hides" do
        marked.update!(email: "marked@example.com", profile_show_email: false)
        expect(search("marked@example")).not_to include("Markedone")
      end

      it "skips the secondary email" do
        marked.update!(email_2: "second@example.com")
        expect(search("second@example")).not_to include("Markedone")
      end

      it "skips the legal first name" do
        marked.update!(legal_first_name: "Legalname")
        expect(search("Legalname")).not_to include("Markedone")
      end

      it "skips addresses" do
        create(:address, addressable: marked, street_address: "123 Hiddenway")
        expect(search("Hiddenway")).not_to include("Markedone")
      end

      it "ignores a phone filter passed by URL" do
        marked.update!(profile_show_phone: true)
        create(:contact_method, contactable: marked, value: "555-0142")
        get people_path, params: { phone: "555-0142" }, headers: turbo_headers
        expect(response.body).to include("Markedone")
      end

      %w[first_name_last_initial first_name_only].each do |preference|
        it "skips the last name when the display preference is #{preference}" do
          marked.update!(last_name: "Hiddensurname", display_name_preference: preference)
          expect(search("Hiddensurname")).not_to include("Markedone")
        end
      end

      it "skips the first name when the display preference is last_name_only" do
        marked.update!(last_name: "Shownsurname", display_name_preference: "last_name_only")
        expect(search("Markedone")).not_to include("Shownsurname")
      end
    end

    describe "sector and age range filters" do
      let(:sector) { create(:sector, :published, name: "Quietsector") }
      let(:age_type) { create(:category_type, :published, name: AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE) }
      let(:age_range) { create(:category, :published, category_type: age_type, name: "Quietage") }

      before do
        create(:sectorable_item, sectorable: marked, sector: sector, is_primary: true)
        create(:categorizable_item, categorizable: marked, category: age_range, is_primary: true)
      end

      it "matches shared sectors" do
        get people_path, params: { sector_ids: [ sector.id ] }, headers: turbo_headers
        expect(response.body).to include("Markedone")
        expect(response.body).not_to include("Plainone")
      end

      it "skips sectors the person hides" do
        marked.update!(profile_show_sectors: false)
        get people_path, params: { sector_ids: [ sector.id ] }, headers: turbo_headers
        expect(response.body).not_to include("Markedone")
      end

      it "matches shared age ranges" do
        get people_path, params: { age_range_ids: [ age_range.id ] }, headers: turbo_headers
        expect(response.body).to include("Markedone")
        expect(response.body).not_to include("Plainone")
      end

      it "skips age ranges the person hides" do
        marked.update!(profile_show_age_ranges: false)
        get people_path, params: { age_range_ids: [ age_range.id ] }, headers: turbo_headers
        expect(response.body).not_to include("Markedone")
      end

      it "shows shared sectors and age ranges in the row" do
        get people_path, headers: turbo_headers
        expect(response.body).to include("Quietsector")
        expect(response.body).to include("Quietage")
      end

      it "leaves hidden sectors and age ranges out of the row" do
        marked.update!(profile_show_sectors: false, profile_show_age_ranges: false)
        get people_path, headers: turbo_headers
        expect(response.body).to include("Markedone")
        expect(response.body).not_to include("Quietsector")
        expect(response.body).not_to include("Quietage")
      end
    end

    describe "organization filters" do
      let(:org) { create(:organization, name: "Quietorg") }

      before { create(:affiliation, person: marked, organization: org, title: "Facilitator", start_date: 1.year.ago, inactive: false) }

      it "matches a shared affiliation by organization name" do
        get people_path, params: { organization_name: "Quietorg" }, headers: turbo_headers
        expect(response.body).to include("Markedone")
        expect(response.body).not_to include("Plainone")
      end

      it "skips affiliations the person hides by organization name" do
        marked.update!(profile_show_affiliations: false)
        get people_path, params: { organization_name: "Quietorg" }, headers: turbo_headers
        expect(response.body).not_to include("Markedone")
      end

      it "matches a shared affiliation by organization id" do
        get people_path, params: { organization_id: org.id }, headers: turbo_headers
        expect(response.body).to include("Markedone")
        expect(response.body).not_to include("Plainone")
      end

      it "skips affiliations the person hides by organization id" do
        marked.update!(profile_show_affiliations: false)
        get people_path, params: { organization_id: org.id }, headers: turbo_headers
        expect(response.body).not_to include("Markedone")
      end

      it "shows shared affiliations in the row" do
        get people_path, headers: turbo_headers
        expect(response.body).to include("Quietorg")
      end

      it "leaves hidden affiliations out of the row" do
        marked.update!(profile_show_affiliations: false)
        get people_path, headers: turbo_headers
        expect(response.body).to include("Markedone")
        expect(response.body).not_to include("Quietorg")
      end
    end
  end

  describe "GET /people (turbo frame) contact info search as an admin" do
    let!(:person) { create(:person, first_name: "Hiddenfacts", profile_show_email: false, profile_show_phone: false) }

    def search(term)
      get people_path, params: { contact_info: term }, headers: turbo_headers
      response.body
    end

    def search_phone(term)
      get people_path, params: { phone: term }, headers: turbo_headers
      response.body
    end

    it "matches an email the person hides" do
      person.update!(email: "hidden@example.com")
      expect(search("hidden@example")).to include("Hiddenfacts")
    end

    it "matches the secondary email" do
      person.update!(email_2: "second@example.com")
      expect(search("second@example")).to include("Hiddenfacts")
    end

    it "matches the legal first name" do
      person.update!(legal_first_name: "Legalname")
      expect(search("Legalname")).to include("Hiddenfacts")
    end

    it "matches a phone the person hides via the phone filter" do
      create(:contact_method, contactable: person, value: "555-0142")
      expect(search_phone("555-0142")).to include("Hiddenfacts")
    end

    it "matches an inactive phone via the phone filter" do
      create(:contact_method, contactable: person, value: "555-0142", inactive: true)
      expect(search_phone("555-0142")).to include("Hiddenfacts")
    end

    %w[first_name_last_initial first_name_only].each do |preference|
      it "matches the last name when the display preference is #{preference}" do
        person.update!(last_name: "Hiddensurname", display_name_preference: preference)
        expect(search("Hiddensurname")).to include("Hiddenfacts")
      end
    end

    it "matches the first name when the display preference is last_name_only" do
      person.update!(last_name: "Shownsurname", display_name_preference: "last_name_only")
      expect(search("Hiddenfacts")).to include("Shownsurname")
    end
  end

  describe "GET /people (turbo frame) sector and age range filters as an admin" do
    let(:sector) { create(:sector, :published, name: "Quietsector") }
    let(:age_type) { create(:category_type, :published, name: AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE) }
    let(:age_range) { create(:category, :published, category_type: age_type, name: "Quietage") }
    let!(:person) { create(:person, first_name: "Hiddenfacts", profile_show_sectors: false, profile_show_age_ranges: false) }

    before do
      create(:sectorable_item, sectorable: person, sector: sector, is_primary: true)
      create(:categorizable_item, categorizable: person, category: age_range, is_primary: true)
    end

    it "matches sectors the person hides" do
      get people_path, params: { sector_ids: [ sector.id ] }, headers: turbo_headers
      expect(response.body).to include("Hiddenfacts")
    end

    it "matches age ranges the person hides" do
      get people_path, params: { age_range_ids: [ age_range.id ] }, headers: turbo_headers
      expect(response.body).to include("Hiddenfacts")
    end

    it "shows hidden sectors and age ranges in the row" do
      get people_path, headers: turbo_headers
      expect(response.body).to include("Quietsector")
      expect(response.body).to include("Quietage")
    end
  end

  describe "GET /people (turbo frame) sector and age range filters match only tagged people" do
    let(:age_type) { create(:category_type, :published, name: AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE) }
    let(:target_sector) { create(:sector, :published, name: "Targetsector") }
    let(:other_sector) { create(:sector, :published, name: "Othersector") }
    let(:target_age) { create(:category, :published, category_type: age_type, name: "Targetage") }
    let(:other_age) { create(:category, :published, category_type: age_type, name: "Otherage") }

    def published_person(first_name)
      person = create(:person, first_name: first_name, last_name: "Facil", profile_is_searchable: true)
      create(:affiliation, person: person, title: "Facilitator", start_date: 1.year.ago, inactive: false)
      person
    end

    def tag(person, sector:, age:, primary:)
      create(:sectorable_item, sectorable: person, sector: sector, is_primary: primary)
      create(:categorizable_item, categorizable: person, category: age, is_primary: primary)
    end

    before do
      tag(published_person("Primarymatch"), sector: target_sector, age: target_age, primary: true)
      additional = published_person("Additionalmatch")
      tag(additional, sector: other_sector, age: other_age, primary: true)
      tag(additional, sector: target_sector, age: target_age, primary: false)
      tag(published_person("Differenttags"), sector: other_sector, age: other_age, primary: true)
      published_person("Notags")
    end

    shared_examples "a tag filter" do |param, target, other|
      it "returns people tagged with it as primary or additional, and no one else" do
        get people_path, params: { param => [ send(target).id ] }, headers: turbo_headers

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Primarymatch")
        expect(response.body).to include("Additionalmatch")
        expect(response.body).not_to include("Differenttags")
        expect(response.body).not_to include("Notags")
      end

      it "returns people tagged with any of several selections" do
        get people_path, params: { param => [ send(target).id, send(other).id ] }, headers: turbo_headers

        expect(response.body).to include("Primarymatch")
        expect(response.body).to include("Additionalmatch")
        expect(response.body).to include("Differenttags")
        expect(response.body).not_to include("Notags")
      end
    end

    context "as an admin" do
      it_behaves_like "a tag filter", :sector_ids, :target_sector, :other_sector
      it_behaves_like "a tag filter", :age_range_ids, :target_age, :other_age
    end

    context "as a non-admin" do
      before { sign_in create(:user) }

      it_behaves_like "a tag filter", :sector_ids, :target_sector, :other_sector
      it_behaves_like "a tag filter", :age_range_ids, :target_age, :other_age
    end
  end

  describe "GET /people (turbo frame) organization filters as an admin" do
    let(:org) { create(:organization, name: "Quietorg") }
    let!(:person) { create(:person, first_name: "Hiddenfacts", profile_show_affiliations: false) }

    before { create(:affiliation, person: person, organization: org) }

    it "matches affiliations the person hides by organization name" do
      get people_path, params: { organization_name: "Quietorg" }, headers: turbo_headers
      expect(response.body).to include("Hiddenfacts")
    end

    it "matches affiliations the person hides by organization id" do
      get people_path, params: { organization_id: org.id }, headers: turbo_headers
      expect(response.body).to include("Hiddenfacts")
    end

    it "shows hidden affiliations in the row" do
      get people_path, headers: turbo_headers
      expect(response.body).to include("Quietorg")
    end
  end

  describe "GET /people?organization_id=X (full page)" do
    let!(:org) { create(:organization, name: "Scoped Org") }

    it "surfaces a chip naming the scoped organization" do
      get people_path, params: { organization_id: org.id }
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Filtered to")
      expect(response.body).to include("Scoped Org")
    end

    it "preserves the organization_id filter when the search form is submitted" do
      get people_path, params: { organization_id: org.id }
      page = Capybara.string(response.body)
      expect(page).to have_css("input[type=hidden][name=organization_id][value='#{org.id}']", visible: :all)
    end
  end
end
