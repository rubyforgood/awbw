require "rails_helper"

RSpec.describe StaffTagging, type: :model do
  it "is valid with a tag and a taggable" do
    expect(build(:staff_tagging)).to be_valid
  end

  it "prevents tagging the same record with the same tag twice" do
    person = create(:person)
    tag = create(:staff_tag)
    create(:staff_tagging, staff_tag: tag, staff_taggable: person)

    dup = build(:staff_tagging, staff_tag: tag, staff_taggable: person)
    expect(dup).not_to be_valid
    expect(dup.errors[:staff_tag_id]).to be_present
  end

  it "records who applied the tag" do
    admin = create(:user, :admin)
    tagging = create(:staff_tagging, created_by: admin)

    expect(tagging.created_by).to eq(admin)
  end

  it "stamps created_by and updated_by from Current.user" do
    admin = create(:user, :admin)
    Current.user = admin
    tagging = create(:staff_tagging)

    expect(tagging.created_by).to eq(admin)
    expect(tagging.updated_by).to eq(admin)
  ensure
    Current.user = nil
  end

  describe ".search_by_params" do
    it "filters by staff tag" do
      wanted = create(:staff_tag)
      kept = create(:staff_tagging, staff_tag: wanted)
      dropped = create(:staff_tagging, staff_tag: create(:staff_tag))

      results = described_class.search_by_params(staff_tag_ids: wanted.id)

      expect(results).to include(kept)
      expect(results).not_to include(dropped)
    end

    it "matches the tagged person by name" do
      hit = create(:staff_tagging, staff_taggable: create(:person, first_name: "Zelda", last_name: "Match"))
      miss = create(:staff_tagging, staff_taggable: create(:person, first_name: "Other", last_name: "Person"))

      results = described_class.search_by_params(query: "Zelda")

      expect(results).to include(hit)
      expect(results).not_to include(miss)
    end

    it "matches the tagged person by affiliated organization name" do
      person = create(:person)
      create(:affiliation, person: person, organization: create(:organization, name: "Rare Org"))
      hit = create(:staff_tagging, staff_taggable: person)
      miss = create(:staff_tagging, staff_taggable: create(:person))

      results = described_class.search_by_params(query: "Rare Org")

      expect(results).to include(hit)
      expect(results).not_to include(miss)
    end

    it "matches on comment content" do
      hit = create(:staff_tagging)
      create(:comment, commentable: hit, body: "needs a follow-up call")
      miss = create(:staff_tagging)

      results = described_class.search_by_params(content: "follow-up")

      expect(results).to include(hit)
      expect(results).not_to include(miss)
    end

    it "matches on communication content" do
      hit = create(:staff_tagging)
      create(:notification, noticeable: hit, email_subject: "quarterly outreach")
      miss = create(:staff_tagging)

      results = described_class.search_by_params(content: "quarterly")

      expect(results).to include(hit)
      expect(results).not_to include(miss)
    end

    it "filters by marked status" do
      marked = create(:staff_tagging, :marked)
      unmarked = create(:staff_tagging)

      expect(described_class.search_by_params(marked: "true")).to contain_exactly(marked)
      expect(described_class.search_by_params(marked: "false")).to contain_exactly(unmarked)
    end
  end
end
