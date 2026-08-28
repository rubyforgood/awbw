require "rails_helper"

RSpec.describe AhoyTrackable do
  # Events are buffered here and written by ApplicationController's after_action,
  # so a model-level spec reads the buffer rather than the table.
  def buffered
    Analytics::LifecycleBuffer.store
  end

  def event_named(name)
    buffered.find { |event| event[:name] == name }
  end

  before do
    Current.user = create(:user)
    Analytics::LifecycleBuffer.store.clear
  end

  after { Current.user = nil }

  describe "rich text" do
    let(:event) { create(:event) }

    it "records a rich text edit as a change on the record's own event" do
      Analytics::LifecycleBuffer.store.clear

      event.update!(rhino_description: "<p>Bring a friend</p>", title: "Renamed")

      changes = event_named("update.event")[:properties][:changes]
      expect(changes["rhino_description"]).to eq({ before: "", after: "Bring a friend" })
      expect(changes["title"]).to be_present
    end

    it "stores the plain text rather than the markup" do
      Analytics::LifecycleBuffer.store.clear

      event.update!(rhino_description: "<p>Bring <strong>a friend</strong></p>")

      after_text = event_named("update.event")[:properties][:changes]["rhino_description"][:after]
      expect(after_text).to eq("Bring a friend")
      expect(after_text).not_to include("<")
    end

    it "records an edit that touches nothing but the rich text" do
      event.update!(rhino_description: "<p>First</p>")
      Analytics::LifecycleBuffer.store.clear

      event.update!(rhino_description: "<p>Second</p>")

      expect(event_named("update.event")[:properties][:changes]["rhino_description"])
        .to eq({ before: "First", after: "Second" })
    end

    it "truncates a long body to a preview" do
      Analytics::LifecycleBuffer.store.clear

      event.update!(rhino_description: "<p>#{"word " * 200}</p>")

      after_text = event_named("update.event")[:properties][:changes]["rhino_description"][:after]
      expect(after_text.length).to eq(AhoyTrackable::RICH_TEXT_PREVIEW_LIMIT)
      expect(after_text).to end_with("...")
    end

    it "records nothing when the rich text is saved unchanged" do
      event.update!(rhino_description: "<p>Same</p>")
      Analytics::LifecycleBuffer.store.clear

      event.update!(rhino_description: "<p>Same</p>")

      expect(event_named("update.event")).to be_nil
    end
  end

  describe "blank-to-blank changes" do
    it "records nothing for a field that was blank before and after" do
      organization = create(:organization, email: nil)
      Analytics::LifecycleBuffer.store.clear

      organization.update!(email: "", name: "Renamed")

      changes = event_named("update.organization")[:properties][:changes]
      expect(changes.keys).to contain_exactly("name")
    end
  end

  describe "nested records" do
    it "records an added nested record on the parent's event" do
      registration = create(:event_registration)
      Analytics::LifecycleBuffer.store.clear

      registration.update!(comments_attributes: [ { body: "Called the registrant" } ])

      added = event_named("update.event_registration")[:properties][:association_changes][:comments].first
      expect(added).to include(action: "added", type: "Comment")
    end

    it "records what an added nested record said, once it has an id" do
      registration = create(:event_registration)
      Analytics::LifecycleBuffer.store.clear

      registration.update!(comments_attributes: [ { body: "Left a voicemail", topic: "Payment" } ])

      added = event_named("update.event_registration")[:properties][:association_changes][:comments].first
      expect(added[:attributes]).to eq({ "body" => "Left a voicemail", "topic" => "Payment" })
      expect(added[:id]).to eq(registration.comments.reload.first.id)
    end

    it "leaves keys and timestamps out of what an added record said" do
      registration = create(:event_registration)
      Analytics::LifecycleBuffer.store.clear

      registration.update!(comments_attributes: [ { body: "Left a voicemail" } ])

      added = event_named("update.event_registration")[:properties][:association_changes][:comments].first
      expect(added[:attributes].keys).to contain_exactly("body")
    end

    it "records an edited nested record with its field changes" do
      person = create(:person)
      license = create(:professional_license, person: person, number: "LIC-1")
      person.professional_licenses.load
      Analytics::LifecycleBuffer.store.clear

      person.update!(professional_licenses_attributes: [ { id: license.id, number: "LIC-2" } ])

      edited = event_named("update.person")[:properties][:association_changes][:professional_licenses].first
      expect(edited).to include(action: "updated")
      expect(edited[:changes]["number"]).to eq({ before: "LIC-1", after: "LIC-2" })
    end

    it "records a removed nested record" do
      person = create(:person)
      license = create(:professional_license, person: person)
      person.professional_licenses.load
      Analytics::LifecycleBuffer.store.clear

      person.update!(professional_licenses_attributes: [ { id: license.id, _destroy: "1" } ])

      removed = event_named("update.person")[:properties][:association_changes][:professional_licenses].first
      expect(removed).to include(action: "removed", id: license.id, type: "ProfessionalLicense")
      expect(removed[:attributes]).to include("number" => license.number)
    end

    it "records a staff tag given to a person on the person's own event" do
      person = create(:person)
      tag = create(:staff_tag)
      Analytics::LifecycleBuffer.store.clear

      person.update!(staff_taggings_attributes: [ { staff_tag_id: tag.id } ])

      tagged = event_named("update.person")[:properties][:association_changes][:staff_taggings].first
      expect(tagged).to include(action: "added", type: "StaffTagging")
    end
  end

  describe "membership changes" do
    it "records an added record as the parent's own update event" do
      person = create(:person)
      category = create(:category)
      Analytics::LifecycleBuffer.store.clear

      person.track_membership_changes(categories: { added: [ category ], removed: [] })

      added = event_named("update.person")[:properties][:association_changes][:categories].first
      expect(added).to eq({ action: "added", type: "Category", id: category.id })
    end

    it "records a removed record" do
      person = create(:person)
      category = create(:category)
      Analytics::LifecycleBuffer.store.clear

      person.track_membership_changes(categories: { added: [], removed: [ category ] })

      removed = event_named("update.person")[:properties][:association_changes][:categories].first
      expect(removed).to include(action: "removed", type: "Category", id: category.id)
    end

    it "records nothing when nothing moved" do
      person = create(:person)
      Analytics::LifecycleBuffer.store.clear

      person.track_membership_changes(categories: { added: [], removed: [] }, sectors: nil)

      expect(event_named("update.person")).to be_nil
    end
  end

  describe "attachments" do
    it "records an added attachment on the record's event" do
      person = create(:person)
      Analytics::LifecycleBuffer.store.clear

      person.update!(avatar: Rack::Test::UploadedFile.new(Rails.root.join("app/assets/images/missing.png"), "image/png"))

      attached = event_named("update.person")[:properties][:association_changes][:avatar_attachment].first
      expect(attached).to include(action: "added", type: "ActiveStorage::Attachment", filename: "missing.png")
    end

    it "keeps the name of a removed attachment, the blob being gone afterwards" do
      person = create(:person)
      person.update!(avatar: Rack::Test::UploadedFile.new(Rails.root.join("app/assets/images/missing.png"), "image/png"))
      Analytics::LifecycleBuffer.store.clear

      person.update!(avatar: nil)

      removed = event_named("update.person")[:properties][:association_changes][:avatar_attachment].first
      expect(removed).to include(action: "removed", filename: "missing.png")
    end
  end
end
