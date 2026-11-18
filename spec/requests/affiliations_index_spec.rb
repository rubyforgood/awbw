require "rails_helper"

RSpec.describe "Affiliations index", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:frame_headers) { { "Turbo-Frame" => "affiliations_results" } }
  let(:alpha_org) { create(:organization, name: "Alpha Arts Org") }
  let(:beta_org) { create(:organization, name: "Beta Builders Org") }
  let(:ana) { create(:person, first_name: "Ana", last_name: "Aardvark") }
  let(:zed) { create(:person, first_name: "Zed", last_name: "Zebra") }
  let!(:facilitator_row) do
    create(:affiliation, person: ana, organization: alpha_org, title: "Facilitator",
                         start_date: Date.new(2015, 3, 1), filemaker_code: "PS100")
  end
  let!(:job_row) do
    create(:affiliation, person: zed, organization: beta_org, title: "Director",
                         start_date: Date.new(2020, 1, 1), end_date: Date.new(2021, 6, 1), primary_contact: true)
  end

  def results(params = {})
    get affiliations_path(params), headers: frame_headers
    expect(response).to be_successful
    response.body
  end

  def ids_in(body)
    Capybara.string(body).all("[id^='affiliation_']").filter_map { |node| node[:id][/\Aaffiliation_(\d+)\z/, 1]&.to_i }
  end

  context "as a non-admin" do
    it "is not allowed" do
      sign_in create(:user)
      get affiliations_path
      expect(response).to redirect_to(root_path)
    end
  end

  context "as an admin" do
    before { sign_in admin }

    it "renders the page shell with the lazy results frame" do
      get affiliations_path
      expect(response).to be_successful
      expect(response.body).to include("affiliations_results")
    end

    it "lists every affiliation with person first, sorted by person" do
      expect(ids_in(results)).to eq([ facilitator_row.id, job_row.id ])
    end

    it "sorts by a column header, descending" do
      expect(ids_in(results(sort: "start_date", direction: "desc"))).to eq([ job_row.id, facilitator_row.id ])
    end

    it "filters by kind" do
      expect(ids_in(results(kind: "facilitator"))).to eq([ facilitator_row.id ])
      expect(ids_in(results(kind: "job"))).to eq([ job_row.id ])
    end

    it "finds untitled job affiliations" do
      untitled = create(:affiliation, person: zed, organization: alpha_org, title: nil)
      expect(ids_in(results(kind: "untitled"))).to eq([ untitled.id ])
    end

    it "searches by person or organization name" do
      expect(ids_in(results(query: "Zebra"))).to eq([ job_row.id ])
      expect(ids_in(results(query: "Alpha"))).to eq([ facilitator_row.id ])
    end

    it "filters by status, including zero-length" do
      zero = create(:affiliation, person: zed, organization: alpha_org, title: "Facilitator",
                                  start_date: Date.new(2024, 5, 1), end_date: Date.new(2024, 5, 1))
      expect(ids_in(results(status: "Active"))).to eq([ facilitator_row.id ])
      expect(ids_in(results(status: "Inactive"))).to contain_exactly(job_row.id, zero.id)
      expect(ids_in(results(status: "Zero-length"))).to eq([ zero.id ])
    end

    it "filters by where the affiliation came from" do
      FmPersonnel.create!(fm_id: "PS100", data: {})
      FmPeopleToOrganization.create!(fm_id: "RC7", data: {})
      job_row.update_column(:filemaker_code, "RC7")
      expect(ids_in(results(source: "fm_personnel"))).to eq([ facilitator_row.id ])
      expect(ids_in(results(source: "fm_people_to_organizations"))).to eq([ job_row.id ])
      job_row.update_column(:filemaker_code, nil)
      expect(ids_in(results(source: "manual"))).to eq([ job_row.id ])
    end

    it "filters by comments, comment text, address, primary contact, and year" do
      create(:comment, commentable: facilitator_row, topic: "FileMaker import", body: "Ends 2015-12-31, a stand-in.")
      address = create(:address, addressable: beta_org)
      job_row.update_column(:organization_address_id, address.id)

      expect(ids_in(results(comments: "yes"))).to eq([ facilitator_row.id ])
      expect(ids_in(results(comments: "no"))).to eq([ job_row.id ])
      expect(ids_in(results(comment_text: "stand-in"))).to eq([ facilitator_row.id ])
      expect(ids_in(results(address: "yes"))).to eq([ job_row.id ])
      expect(ids_in(results(primary: "yes"))).to eq([ job_row.id ])
      expect(ids_in(results(start_year: "2015"))).to eq([ facilitator_row.id ])
      expect(ids_in(results(end_year: "2021"))).to eq([ job_row.id ])
    end

    it "filters by whether the person has any registrations" do
      create(:event_registration, registrant: zed)

      expect(ids_in(results(registrations: "yes"))).to eq([ job_row.id ])
      expect(ids_in(results(registrations: "no"))).to eq([ facilitator_row.id ])
      expect(ids_in(results)).to eq([ facilitator_row.id, job_row.id ])
    end

    it "filters by FileMaker code and by person or organization id" do
      expect(ids_in(results(filemaker_code: "PS100"))).to eq([ facilitator_row.id ])
      expect(ids_in(results(person_id: zed.id))).to eq([ job_row.id ])
      expect(ids_in(results(organization_id: alpha_org.id))).to eq([ facilitator_row.id ])
    end

    it "shows the first comment with a link to the rest" do
      create(:comment, commentable: facilitator_row, body: "Older note", created_at: 2.days.ago)
      create(:comment, commentable: facilitator_row, body: "Newest note")
      body = results
      expect(body).to include("Newest note")
      expect(body).to include("All 2 comments")
    end
  end

  describe "row links" do
    before { sign_in admin }

    it "offers the person's registrations as events, labelled by id and abbreviation or title" do
      event = create(:event, title: "Spring Training", abbreviation: "SPR26")
      untitled_abbrev = create(:event, title: "Fall Training", abbreviation: nil)
      registration = create(:event_registration, event: event, registrant: zed)
      create(:event_registration, event: untitled_abbrev, registrant: zed)
      create(:event_registration, registrant: ana)
      job_row.update_column(:event_registration_id, registration.id)

      select = Capybara.string(results).find("#event_registration_affiliation_#{job_row.id}")
      expect(select.all("option").map(&:text)).to contain_exactly("—", "##{event.id} · SPR26", "##{untitled_abbrev.id} · Fall Training")
      expect(select.find("option[selected]").text).to eq("##{event.id} · SPR26")
    end

    it "highlights an inactive flag the dates don't back up" do
      facilitator_row.update_column(:inactive, true)
      job_row.update_column(:inactive, true)
      body = Capybara.string(results)

      expect(body).to have_css("#index_inactive_affiliation_#{facilitator_row.id} .bg-orange-100")
      expect(body).to have_no_css("#index_inactive_affiliation_#{job_row.id} .bg-orange-100")
      expect(body).to have_checked_field("inactive_flag_affiliation_#{job_row.id}")
    end

    it "links the FileMaker code to its archive record" do
      FmPersonnel.create!(fm_id: "PS100", data: {})
      body = Capybara.string(results)

      expect(body).to have_link("PS100", href: fm_archive_path("PS100", table: "personnels"))
    end

    it "offers edit and delete on each row" do
      body = Capybara.string(results)
      expect(body).to have_css("a[href='#{edit_affiliation_path(job_row)}'][aria-label='Edit affiliation']")
      expect(body).to have_css("a[href='#{affiliation_path(job_row)}'][data-turbo-method='delete']")
    end

    it "deleting from the index streams the row away" do
      delete affiliation_path(job_row), as: :turbo_stream

      expect(response.body).to include(%(action="remove"), %(target="affiliation_#{job_row.id}"))
      expect(Affiliation.exists?(job_row.id)).to be(false)
    end
  end

  describe "PATCH /affiliations/:id/save_inline" do
    before { sign_in admin }

    it "saves an end date, re-derives inactive, and streams back the flag" do
      patch save_inline_affiliation_path(facilitator_row),
            params: { affiliation: { end_date: 1.year.ago.to_date.iso8601 } }, as: :turbo_stream

      expect(response.media_type).to eq(Mime[:turbo_stream])
      expect(response.body).to include("index_inactive_affiliation_#{facilitator_row.id}")
      expect(facilitator_row.reload.end_date).to eq(1.year.ago.to_date)
      expect(facilitator_row).to be_inactive
    end

    it "saves a hand-set inactive flag that the dates don't imply" do
      patch save_inline_affiliation_path(facilitator_row), params: { affiliation: { inactive: "1" } }, as: :turbo_stream

      expect(facilitator_row.reload).to be_inactive
      expect(response.body).to include("index_inactive_affiliation_#{facilitator_row.id}")
    end

    it "logs each inline change as activity" do
      allow(Analytics::LifecycleBuffer).to receive(:push).and_call_original

      patch save_inline_affiliation_path(job_row), params: { affiliation: { start_date: "2019-02-01" } }, as: :turbo_stream
      patch save_inline_affiliation_path(job_row), params: { affiliation: { inactive: "0" } }, as: :turbo_stream

      %w[start_date inactive].each do |field|
        expect(Analytics::LifecycleBuffer).to have_received(:push).with(
          hash_including(name: "update.affiliation",
                         properties: hash_including(resource_id: job_row.id, changes: hash_including(field)))
        )
      end
    end

    it "links an event by its registration, logs it, and streams back the picker" do
      allow(Analytics::LifecycleBuffer).to receive(:push).and_call_original
      registration = create(:event_registration, registrant: zed)

      patch save_inline_affiliation_path(job_row),
            params: { affiliation: { event_registration_id: registration.id } }, as: :turbo_stream

      expect(job_row.reload.event_registration).to eq(registration)
      expect(response.body).to include("index_event_affiliation_#{job_row.id}")
      expect(Analytics::LifecycleBuffer).to have_received(:push).with(
        hash_including(name: "update.affiliation",
                       properties: hash_including(changes: hash_including("event_registration_id")))
      )
    end

    it "unlinks an event when the picker is cleared" do
      job_row.update_column(:event_registration_id, create(:event_registration, registrant: zed).id)

      patch save_inline_affiliation_path(job_row), params: { affiliation: { event_registration_id: "" } }, as: :turbo_stream

      expect(job_row.reload.event_registration_id).to be_nil
    end

    it "only touches the dates and inactive flag" do
      patch save_inline_affiliation_path(job_row),
            params: { affiliation: { start_date: "2019-02-01", title: "Changed" } }, as: :turbo_stream

      expect(job_row.reload.start_date).to eq(Date.new(2019, 2, 1))
      expect(job_row.title).to eq("Director")
    end

    it "is not allowed for non-admins" do
      sign_in create(:user)
      patch save_inline_affiliation_path(job_row), params: { affiliation: { start_date: "2019-02-01" } }, as: :turbo_stream
      expect(job_row.reload.start_date).to eq(Date.new(2020, 1, 1))
    end
  end
end
