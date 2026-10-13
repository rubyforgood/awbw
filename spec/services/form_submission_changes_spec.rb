require "rails_helper"

RSpec.describe FormSubmissionChanges do
  let(:submission) { create(:form_submission) }

  def stamp(name, resource_type:, resource_id: 0, properties: {})
    create(:ahoy_event, name: name, properties: {
      "resource_type" => resource_type,
      "resource_id" => resource_id,
      "form_submission_id" => submission.id
    }.merge(properties))
  end

  it "groups an organization profile change under the org and labels it replaced" do
    org = create(:organization, name: "Riverside Community Arts")
    stamp("update.organization", resource_type: "Organization", resource_id: org.id,
          properties: { "resource_title" => org.name,
                        "changes" => { "website_url" => { "before" => "old.com", "after" => "new.com" } } })

    group = described_class.new(submission).groups.find { |g| g.record_type == "Organization" }
    expect(group.title).to eq("Riverside Community Arts")
    change = group.changes.first
    expect(change).to have_attributes(outcome: "Replaced", label: "Website", value: "new.com", previous_value: "old.com")
  end

  it "labels a change from blank as filled" do
    person = create(:person)
    stamp("update.person", resource_type: "Person", resource_id: person.id,
          properties: { "changes" => { "racial_ethnic_identity" => { "before" => nil, "after" => "Prefer not to say" } } })

    change = described_class.new(submission).groups.first.changes.first
    expect(change).to have_attributes(outcome: "Filled", value: "Prefer not to say")
  end

  # The sharing preferences store a boolean / an enum key, which would otherwise
  # read as "true" — and `false` is a real choice, not an empty column.
  it "labels a content-sharing change with the wording the person chose" do
    person = create(:person)
    stamp("update.person", resource_type: "Person", resource_id: person.id,
          properties: { "changes" => { "anonymous_contributions" => { "before" => nil, "after" => false } } })

    change = described_class.new(submission).groups.first.changes.first
    expect(change).to have_attributes(
      outcome: "Filled", label: "Content sharing",
      value: Person::ANONYMOUS_CONTRIBUTIONS_OPTIONS[false]
    )
  end

  it "labels a display-name preference change with its option wording" do
    person = create(:person)
    stamp("update.person", resource_type: "Person", resource_id: person.id,
          properties: { "changes" => { "display_name_preference" => { "before" => "full_name", "after" => "first_name_only" } } })

    change = described_class.new(submission).groups.first.changes.first
    expect(change).to have_attributes(
      outcome: "Replaced", label: "Display name",
      value: "First name only", previous_value: "First and last name"
    )
  end

  it "attributes a sector tag to its owner and resolves the sector name" do
    org = create(:organization, name: "Riverside")
    sector = create(:sector, :published, name: "Healthcare")
    stamp("create.sectorable_item", resource_type: "SectorableItem",
          properties: { "attributes" => { "sector_id" => sector.id, "sectorable_type" => "Organization",
                                           "sectorable_id" => org.id, "is_primary" => true } })

    change = described_class.new(submission).groups.find { |g| g.record_type == "Organization" }.changes.first
    expect(change).to have_attributes(outcome: "Added", label: "Sector", value: "Healthcare (primary)")
  end

  it "resolves an age group tag name" do
    person = create(:person)
    category = create(:category, :published, name: "Adolescents (13-17)")
    stamp("create.categorizable_item", resource_type: "CategorizableItem",
          properties: { "attributes" => { "category_id" => category.id, "categorizable_type" => "Person",
                                          "categorizable_id" => person.id, "is_primary" => false } })

    change = described_class.new(submission).groups.find { |g| g.record_type == "Person" }.changes.first
    expect(change).to have_attributes(outcome: "Added", label: "Age group", value: "Adolescents (13-17)")
  end

  # A re-submission that replaces the person's tags destroys the ones it dropped,
  # and the destroy event carries the snapshot the page reads.
  it "reports a sector the submission removed" do
    person = create(:person)
    sector = create(:sector, :published, name: "Housing")
    stamp("destroy.sectorable_item", resource_type: "SectorableItem",
          properties: { "attributes" => { "sector_id" => sector.id, "sectorable_type" => "Person",
                                          "sectorable_id" => person.id } })

    change = described_class.new(submission).groups.find { |g| g.record_type == "Person" }.changes.first
    expect(change).to have_attributes(outcome: "Removed", label: "Sector", value: "Housing")
  end

  # A primary flip is an update, which carries only the changed column — so the
  # owner and the sector come off the tag row itself.
  it "reports a sector the submission demoted, reading the owner off the tag row" do
    person = create(:person)
    sector = create(:sector, :published, name: "Healthcare")
    item = person.sectorable_items.create!(sector: sector, is_primary: false)
    stamp("update.sectorable_item", resource_type: "SectorableItem", resource_id: item.id,
          properties: { "changes" => { "is_primary" => { "before" => true, "after" => false } } })

    changes = described_class.new(submission)
    group = changes.groups.find { |g| g.record_type == "Person" }
    expect(group.record_id).to eq(person.id)
    expect(group.changes.first).to have_attributes(outcome: "Changed", label: "Sector",
                                                   value: "Healthcare (no longer primary)")
    # It edited a tag that was already on file, so the submission reads as edited.
    expect(changes.edited?).to be(true)
  end

  it "ignores bookkeeping records like form answers and the submission itself" do
    stamp("create.form_answer", resource_type: "FormAnswer", resource_id: 1)
    stamp("create.form_submission", resource_type: "FormSubmission", resource_id: submission.id)

    expect(described_class.new(submission).groups).to be_empty
  end

  describe "edited values (changes to records that already existed)" do
    it "counts both replaced and filled values on an existing record" do
      org = create(:organization, name: "Riverside")
      stamp("update.organization", resource_type: "Organization", resource_id: org.id,
            properties: { "resource_title" => org.name, "changes" => {
              "website_url" => { "before" => "old.com", "after" => "new.com" },
              "organization_type" => { "before" => nil, "after" => "Hospital" }
            } })

      changes = described_class.new(submission)
      expect(changes.edited?).to be(true)
      expect(changes.edited_count).to eq(2)
      expect(changes.edited_groups.sum { |group| group.changes.size }).to eq(2)
      expect(changes.edited_groups.first.changes.map(&:outcome)).to contain_exactly("Replaced", "Filled")
    end

    it "does not count a fresh submission that only creates records and adds tags" do
      person = create(:person)
      sector = create(:sector, :published)
      stamp("create.person", resource_type: "Person", resource_id: person.id,
            properties: { "resource_title" => person.full_name, "attributes" => { "first_name" => "Dana" } })
      stamp("create.sectorable_item", resource_type: "SectorableItem",
            properties: { "attributes" => { "sector_id" => sector.id, "sectorable_type" => "Person", "sectorable_id" => person.id } })

      changes = described_class.new(submission)
      expect(changes.edited?).to be(false)
      expect(changes.edited_count).to eq(0)
      expect(changes.edited_groups).to be_empty
    end

    it "surfaces an organization created through the linking process, alongside any fills on it" do
      org = create(:organization, name: "Haven Hills")
      stamp("create.organization", resource_type: "Organization", resource_id: org.id,
            properties: { "resource_title" => org.name })
      stamp("update.organization", resource_type: "Organization", resource_id: org.id,
            properties: { "resource_title" => org.name,
                          "changes" => { "website_url" => { "before" => nil, "after" => "haven.org" } } })

      changes = described_class.new(submission)
      expect(changes.edited?).to be(true)
      expect(changes.edited_count).to eq(2)
      group = changes.edited_groups.find { |g| g.record_type == "Organization" }
      expect(group.changes.map(&:outcome)).to contain_exactly("Added", "Filled")
    end
  end

  describe "field anchors for deep-linking to the record's edit page" do
    it "carries the owner id and anchors own fields to their input, sub-records to their section" do
      person = create(:person)
      stamp("update.person", resource_type: "Person", resource_id: person.id,
            properties: { "changes" => { "racial_ethnic_identity" => { "before" => "a", "after" => "b" } } })
      stamp("update.address", resource_type: "Address", resource_id: 1,
            properties: { "attributes" => { "addressable_type" => "Person", "addressable_id" => person.id },
                          "changes" => { "zip_code" => { "before" => "1", "after" => "2" } } })

      group = described_class.new(submission).groups.find { |g| g.record_type == "Person" }
      expect(group.record_id).to eq(person.id)
      anchors = group.changes.to_h { |c| [ c.label, c.anchor ] }
      expect(anchors["Racial / ethnic identity"]).to eq("person_racial_ethnic_identity")
      expect(anchors["ZIP"]).to eq("addresses")
    end
  end

  it "only reads events stamped with this submission" do
    other = create(:form_submission)
    create(:ahoy_event, name: "update.person", properties: {
      "resource_type" => "Person", "resource_id" => 1, "form_submission_id" => other.id,
      "changes" => { "first_name" => { "before" => "A", "after" => "B" } }
    })

    expect(described_class.new(submission).groups).to be_empty
  end
end
