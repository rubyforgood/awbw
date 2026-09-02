require "rails_helper"

RSpec.describe Ahoy::EventDecorator do
  def decorate(properties)
    create(:ahoy_event, properties: properties).reload.decorate
  end

  def decorate_named(name)
    create(:ahoy_event, name: name).decorate
  end

  def decorate_page(name, properties)
    create(:ahoy_event, name: name, properties: properties).reload.decorate
  end

  describe "#activity_chip" do
    it "reads create as a New chip and update as an Edit chip" do
      expect(decorate_named("create.comment").activity_chip[:label]).to eq("New")
      expect(decorate_named("update.workshop").activity_chip[:label]).to eq("Edit")
    end

    it "humanizes an unmapped action" do
      expect(decorate_named("something.workshop").activity_chip[:label]).to eq("Something")
    end
  end

  describe ".action_keys_for_label" do
    it "maps a chip word back to its raw action prefixes, case-insensitively" do
      expect(described_class.action_keys_for_label("new")).to eq(%w[create])
      expect(described_class.action_keys_for_label("Edit")).to eq(%w[update])
      expect(described_class.action_keys_for_label("search")).to eq(%w[search search_zero])
    end

    it "is empty for a word that isn't a chip label" do
      expect(described_class.action_keys_for_label("workshop")).to eq([])
    end
  end

  describe "auth event details" do
    it "drops the redundant record and updated_by rows, keeping the rest" do
      event = create(:ahoy_event, name: "auth.login", properties: {
        "record_id" => 1, "record_type" => "User", "updated_by_id" => nil,
        "resource_type" => "User", "resource_id" => 1,
        "resource_title" => "Umberto (u@example.com)", "sign_in_count" => 2
      }).reload.decorate

      expect(event.extra_properties.keys).to eq(%w[sign_in_count])
    end
  end

  describe "#activity_resource_label" do
    it "humanizes the resource half of the name" do
      expect(decorate_named("update.workshop_variation").activity_resource_label).to eq("Workshop variation")
      expect(decorate_named("auth.account_deactivated").activity_resource_label).to eq("Account deactivated")
    end
  end

  describe "#resource_link" do
    it "links the resource title to the record's edit page" do
      workshop = create(:workshop)
      event = create(:ahoy_event, name: "create.workshop", resource_type: "Workshop",
                                  resource_id: workshop.id, properties: { "resource_title" => "Feelings Collage" }).decorate

      link = event.resource_link
      expect(link[:text]).to eq("Feelings Collage")
      expect(link[:path]).to eq(Rails.application.routes.url_helpers.edit_workshop_path(workshop))
    end

    it "points a story share menu event at the story share admin page, keeping the record name as the label" do
      sector = create(:sector, :published, name: "Families")
      event = create(:ahoy_event, name: "update.story_share_menu", resource_type: "Sector",
                                  resource_id: sector.id, properties: { "resource_title" => "Families" }).decorate

      expect(event.resource_link[:text]).to eq("Families")
      expect(event.resource_link[:path]).to eq(Rails.application.routes.url_helpers.story_share_admin_path)
    end

    it "is nil when there is no resource title" do
      expect(decorate("source" => "import").resource_link).to be_nil
    end

    it "leaves the path nil when the record no longer exists" do
      event = create(:ahoy_event, name: "create.workshop", resource_type: "Workshop",
                                  resource_id: 0, properties: { "resource_title" => "Ghost" }).decorate
      expect(event.resource_link[:path]).to be_nil
    end

    it "points a comment at the record it was left on, and surfaces its topic/body" do
      person = create(:person)
      comment = create(:comment, commentable: person, topic: "Follow-up", body: "Called to confirm.")
      event = create(:ahoy_event, name: "create.comment", resource_type: "Comment",
                                  resource_id: comment.id, properties: { "resource_title" => "Comment" }).decorate

      expect(event.resource_link[:text]).to eq("Profile")
      expect(event.resource_link[:path]).to eq(Rails.application.routes.url_helpers.edit_person_path(person))
      expect(event.comment_note).to eq(topic: "Follow-up", body: "Called to confirm.")
    end

    it "flags a flagged comment" do
      comment = create(:comment, commentable: create(:person), flagged: true)
      event = create(:ahoy_event, name: "create.comment", resource_type: "Comment",
                                  resource_id: comment.id, properties: { "resource_title" => "Comment" }).decorate
      expect(event.comment_flagged?).to be(true)
    end

    it "labels an affiliation as its title and organization" do
      org = create(:organization, name: "Harbor Shelter")
      affiliation = create(:affiliation, title: "Facilitator", organization: org)
      event = create(:ahoy_event, name: "update.affiliation", resource_type: "Affiliation",
                                  resource_id: affiliation.id, properties: { "resource_title" => "Facilitator" }).decorate

      expect(event.resource_link[:text]).to eq("Facilitator · Harbor Shelter")
      expect(event.resource_link[:path]).to eq(Rails.application.routes.url_helpers.edit_affiliation_path(affiliation))
    end

    it "appends an affiliation's date span, or 'present' while active" do
      org = create(:organization, name: "Harbor Shelter")
      ended = create(:affiliation, title: "Facilitator", organization: org,
                                   start_date: Date.new(2025, 8, 1), end_date: Date.new(2026, 2, 1))
      active = create(:affiliation, title: "Facilitator", organization: org,
                                    start_date: Date.new(2025, 8, 1), end_date: nil)

      ended_event = create(:ahoy_event, name: "update.affiliation", resource_type: "Affiliation",
                                        resource_id: ended.id, properties: {}).decorate
      active_event = create(:ahoy_event, name: "update.affiliation", resource_type: "Affiliation",
                                         resource_id: active.id, properties: {}).decorate

      expect(ended_event.resource_link[:text]).to eq("Facilitator · Harbor Shelter · Aug'25 - Feb'26")
      expect(active_event.resource_link[:text]).to eq("Facilitator · Harbor Shelter · Aug'25 - present")
    end

    it "labels an event registration with the event and abbreviated start month" do
      registration = create(:event_registration)
      registration.event.update!(title: "Spring Training", start_date: Time.zone.local(2025, 9, 1))
      event = create(:ahoy_event, name: "update.event_registration", resource_type: "EventRegistration",
                                  resource_id: registration.id, properties: { "resource_title" => "reg" }).decorate

      expect(event.resource_link[:text]).to eq("Registration: Spring Training · Sep'25")
    end

    it "labels a scholarship as its amount, grant, and funder" do
      org = create(:organization, name: "Acme Foundation")
      grant = create(:grant, name: "Healing Arts Fund", funder: org)
      scholarship = create(:scholarship, amount_cents: 24_000, grant: grant)
      event = create(:ahoy_event, name: "create.scholarship", resource_type: "Scholarship",
                                  resource_id: scholarship.id, properties: {}).decorate

      expect(event.resource_link[:text]).to eq("$240 Healing Arts Fund · Acme Foundation")
    end

    it "labels a CE registration as its hours and license" do
      ce = create(:continuing_education_registration, hours: 13)
      ce.professional_license.update!(kind: "LMFT", number: "2345")
      event = create(:ahoy_event, name: "create.continuing_education_registration",
                                  resource_type: "ContinuingEducationRegistration",
                                  resource_id: ce.id, properties: {}).decorate

      expect(event.resource_link[:text]).to eq("13 hours · LMFT 2345")
    end

    it "labels a payment as what it's allocated to" do
      registration = create(:event_registration)
      payment = create(:payment)
      create(:allocation, source: payment, allocatable: registration)
      event = create(:ahoy_event, name: "create.payment", resource_type: "Payment",
                                  resource_id: payment.id, properties: { "resource_title" => "Membership dues" }).decorate

      expect(event.resource_link[:text]).to include("Event registration for")
      expect(event.resource_link[:path]).to eq(Rails.application.routes.url_helpers.edit_event_registration_path(registration))
    end
  end

  describe "#activity_path" do
    let(:routes) { Rails.application.routes.url_helpers }

    it "uses the record's edit page for a record-backed event" do
      workshop = create(:workshop)
      event = create(:ahoy_event, name: "view.workshop", resource_type: "Workshop",
                                  resource_id: workshop.id, properties: { "resource_title" => "Feelings Collage" }).decorate

      expect(event.activity_path).to eq(routes.edit_workshop_path(workshop))
    end

    it "links a record-less index view to its index page" do
      expect(decorate_named("view.tags").activity_path).to eq(routes.tags_path)
      expect(decorate_named("view.comments").activity_path).to eq(routes.comments_path)
      expect(decorate_named("view.taggings").activity_path).to eq(routes.taggings_path)
      expect(decorate_named("view.notifications").activity_path).to eq(routes.notifications_path)
      expect(decorate_named("view.bulk_payments").activity_path).to eq(routes.bulk_payments_path)
      expect(decorate_named("view.admin.data_health").activity_path).to eq(routes.admin_data_health_path)
    end

    it "links a person-scoped page view using its person_id property" do
      event = decorate_page("view.person_all_comments", "person_id" => 42)
      expect(event.activity_path).to eq(routes.all_comments_person_path(42))
    end

    it "links a collection report to its collection path" do
      expect(decorate_named("view.events.reports").activity_path).to eq(routes.reports_events_path)
    end

    it "keeps the event_id filter on a collection report scoped to one event" do
      event = decorate_page("view.events.reports", "event_id" => 7)
      expect(event.activity_path).to eq(routes.reports_events_path(event_id: 7))
    end

    it "links a per-event page view to that event's member page" do
      event = decorate_page("view.events.roster", "event_id" => 9)
      expect(event.activity_path).to eq(routes.roster_event_path(9))
    end

    it "does not link a POST-only action event that has no page" do
      event = decorate_page("view.events.send_reminder", "event_id" => 3)
      expect(event.activity_path).to be_nil
    end

    it "is nil for a record-less view with no known page" do
      expect(decorate_named("view.mystery").activity_path).to be_nil
    end
  end

  describe "#extra_properties" do
    it "drops the keys already shown in their own columns" do
      event = decorate(
        "resource_type" => "Workshop",
        "resource_id" => 1,
        "resource_title" => "Test",
        "source" => "import"
      )
      expect(event.extra_properties).to eq("source" => "import")
    end

    it "is empty when only the redundant keys are present" do
      event = decorate("resource_type" => "Workshop", "resource_id" => 1, "resource_title" => "Test")
      expect(event.extra_details?).to be(false)
    end
  end

  describe "#changes?" do
    it "is true for an update event with a changes diff" do
      event = decorate("changes" => { "title" => { "before" => "Old", "after" => "New" } })
      expect(event.changes?).to be(true)
    end

    it "is false when there is no changes diff" do
      event = decorate("resource_title" => "Test")
      expect(event.changes?).to be(false)
    end
  end

  describe "#changes_summary" do
    it "humanizes the field and formats before/after values" do
      event = decorate(
        "changes" => {
          "display_name" => { "before" => "Old", "after" => "New" },
          "active" => { "before" => false, "after" => true },
          "note" => { "before" => nil, "after" => "" }
        }
      )

      expect(event.changes_summary).to match_array(
        [
          { field: "Display name", before: "Old", after: "New" },
          { field: "Active", before: "No", after: "Yes" }
        ]
      )
    end

    it "leaves out a field that was blank before and after" do
      event = decorate("changes" => { "note" => { "before" => nil, "after" => "" } })

      expect(event.changes_summary).to eq([])
    end

    it "is empty when the event has no changes" do
      event = decorate("resource_title" => "Test")
      expect(event.changes_summary).to eq([])
    end
  end

  describe "#detail_rows" do
    it "flattens scalar extras into humanized rows" do
      event = decorate("resource_title" => "Test", "source" => "import", "result_count" => 3)
      expect(event.detail_rows).to match_array(
        [
          { label: "Source", value: "import", depth: 0 },
          { label: "Results found", value: "3", depth: 0 }
        ]
      )
    end

    it "labels both result_count and the legacy page_result_count as Results found" do
      current = decorate("result_count" => 8)
      legacy = decorate("page_result_count" => 21)
      expect(current.detail_rows).to eq([ { label: "Results found", value: "8", depth: 0 } ])
      expect(legacy.detail_rows).to eq([ { label: "Results found", value: "21", depth: 0 } ])
    end

    it "indents a nested hash under its label" do
      event = decorate("keywords" => { "full_text" => "watercolor" })
      expect(event.detail_rows).to eq(
        [
          { label: "Keywords", value: nil, depth: 0 },
          { label: "Full text", value: "watercolor", depth: 1 }
        ]
      )
    end

    it "joins an array of scalars into one row" do
      event = decorate("sectors" => %w[Veterans Youth])
      expect(event.detail_rows).to eq([ { label: "Sectors", value: "Veterans, Youth", depth: 0 } ])
    end

    it "collapses an array of named entities onto one line" do
      event = decorate(
        "filters" => {
          "sectors" => [ { "id" => 9, "name" => "Education" }, { "id" => 2, "name" => "Youth" } ],
          "categories" => [ { "id" => 10, "name" => "Journaling", "type" => "ArtType" } ]
        }
      )
      expect(event.detail_rows).to eq(
        [
          { label: "Filters", value: nil, depth: 0 },
          { label: "Sectors", value: "Education, Youth", depth: 1 },
          { label: "Categories", value: "Journaling (Art type)", depth: 1 }
        ]
      )
    end

    it "excludes the changes diff (rendered separately)" do
      event = decorate("changes" => { "title" => { "before" => "A", "after" => "B" } })
      expect(event.detail_rows).to eq([])
    end
  end

  describe "record references" do
    it "links an association change to the record's show page" do
      workshop = create(:workshop)
      event = decorate(
        "association_changes" => {
          "workshops" => [ { "action" => "added", "id" => workshop.id, "type" => "Workshop" } ]
        }
      )
      rows = event.detail_rows

      header = rows.find { |r| r[:label] == "Association changes" }
      expect(header[:value]).to be_nil

      link_row = rows.find { |r| r[:link] }
      expect(link_row[:action]).to eq("added")
      expect(link_row[:link][:text]).to eq(workshop.title)
      expect(link_row[:link][:path]).to eq(Rails.application.routes.url_helpers.workshop_path(workshop))
    end

    it "falls back to type + id when the record is gone" do
      event = decorate(
        "associated_records" => [ { "record_type" => "Workshop", "record_id" => 0 } ]
      )
      link_row = event.detail_rows.find { |r| r[:link] }
      expect(link_row[:link][:text]).to eq("Workshop #0")
      expect(link_row[:link][:path]).to be_nil
    end

    it "resolves references from the page record_cache without its own query" do
      workshop = create(:workshop)
      cache = { [ "Workshop", workshop.id ] => workshop }
      event = create(:ahoy_event, properties: {
        "association_changes" => { "workshops" => [ { "action" => "added", "id" => workshop.id, "type" => "Workshop" } ] }
      }).reload.decorate(context: { record_cache: cache })

      link_row = nil
      queries = 0
      counter = ->(_n, _s, _f, _i, payload) { queries += 1 if payload[:sql]&.include?("`workshops`") }
      ActiveSupport::Notifications.subscribed(counter, "sql.active_record") do
        link_row = event.detail_rows.find { |r| r[:link] }
      end

      expect(link_row[:link][:text]).to eq(workshop.title)
      expect(queries).to eq(0)
    end
  end

  describe "a reference whose record has a broken label" do
    it "falls back to the type and id instead of raising" do
      organization = create(:organization)
      tagging = create(:sectorable_item, sectorable: organization, sector: create(:sector))
      allow_any_instance_of(SectorableItem).to receive(:title).and_raise(NoMethodError)
      event = create(
        :ahoy_event,
        name: "update.organization",
        resource_type: "Organization",
        resource_id: organization.id,
        properties: {
          resource_type: "Organization", resource_id: organization.id,
          association_changes: { sectorable_items: [ { action: "added", type: "SectorableItem", id: tagging.id } ] }
        }
      )

      rows = event.decorate.detail_rows

      expect(rows.map { |row| row[:link] }.compact.first[:text]).to eq("SectorableItem ##{tagging.id}")
    end
  end

  describe "detail rows for a nested record" do
    let(:organization) { create(:organization) }

    def event_with(association_changes)
      create(
        :ahoy_event,
        name: "update.organization",
        resource_type: "Organization",
        resource_id: organization.id,
        properties: {
          resource_type: "Organization", resource_id: organization.id,
          association_changes: association_changes
        }
      ).decorate
    end

    it "reads the topic first and marks it as the heading" do
      rows = event_with(comments: [ {
        action: "added", type: "Comment", id: 1,
        attributes: { "body" => "Left a voicemail", "topic" => "Payment" }
      } ]).detail_rows

      labelled = rows.select { |row| row[:value].present? }
      expect(labelled.map { |row| row[:label] }).to eq([ "Topic", "Body" ])
      expect(labelled.first[:emphasis]).to be(true)
      expect(labelled.last[:emphasis]).to be_nil
    end

    it "renders a diff as before then after, whatever order it was stored in" do
      rows = event_with(addresses: [ {
        action: "updated", type: "Address", id: 1,
        changes: { "city" => { "after" => "Long Beach", "before" => "Lake Lamar" } }
      } ]).detail_rows

      change = rows.find { |row| row[:change] }
      expect(change[:label]).to eq("City")
      expect(change[:change]).to eq({ before: "Lake Lamar", after: "Long Beach" })
    end

    it "leaves out a field that was blank before and after" do
      rows = event_with(addresses: [ {
        action: "updated", type: "Address", id: 1,
        changes: { "phone" => { "before" => nil, "after" => "" },
                   "city" => { "before" => "Lake Lamar", "after" => "Long Beach" } }
      } ]).detail_rows

      expect(rows.filter_map { |row| row[:label] if row[:change] }).to eq([ "City" ])
    end

    it "reads an added attachment as its filename" do
      rows = event_with(avatar_attachment: [ {
        action: "added", type: "ActiveStorage::Attachment", filename: "headshot.png"
      } ]).detail_rows

      attachment = rows.last
      expect(attachment[:action]).to eq("added")
      expect(attachment[:value]).to eq("headshot.png")
      expect(rows.map { |row| row[:value] }).not_to include(a_string_including("ActiveStorage"))
    end

    it "reads a removed attachment as its name" do
      rows = event_with(avatar_attachment: [ {
        action: "removed", type: "ActiveStorage::Attachment", filename: "headshot.png"
      } ]).detail_rows

      attachment = rows.last
      expect(attachment[:action]).to eq("removed")
      expect(attachment[:value]).to eq("headshot.png")
    end

    it "falls back to the action alone for an older entry with no filename" do
      rows = event_with(avatar_attachment: [ {
        action: "removed", type: "ActiveStorage::Attachment"
      } ]).detail_rows

      attachment = rows.last
      expect(attachment[:action]).to eq("removed")
      expect(attachment[:value]).to be_nil
    end
  end
end
