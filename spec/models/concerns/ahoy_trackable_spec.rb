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

  describe "nested records" do
    it "records an added nested record on the parent's event" do
      registration = create(:event_registration)
      Analytics::LifecycleBuffer.store.clear

      registration.update!(comments_attributes: [ { body: "Called the registrant" } ])

      added = event_named("update.event_registration")[:properties][:association_changes][:comments].first
      expect(added).to include(action: "added", type: "Comment")
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
    end
  end

  describe "attachments" do
    it "records an added attachment on the record's event" do
      person = create(:person)
      Analytics::LifecycleBuffer.store.clear

      person.update!(avatar: Rack::Test::UploadedFile.new(Rails.root.join("app/assets/images/missing.png"), "image/png"))

      attached = event_named("update.person")[:properties][:association_changes][:avatar_attachment].first
      expect(attached).to include(action: "added", type: "ActiveStorage::Attachment")
    end
  end
end
