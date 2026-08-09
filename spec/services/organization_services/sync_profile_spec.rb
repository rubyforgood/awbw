require "rails_helper"

RSpec.describe OrganizationServices::SyncProfile do
  let(:organization) { create(:organization) }

  describe "website_url" do
    it "sets the website from the submitted value" do
      described_class.call(organization: organization, website: " helpinghands.org ")

      expect(organization.reload.website_url).to eq("helpinghands.org")
    end

    it "does not clobber an existing website with a blank answer" do
      organization.update!(website_url: "https://existing.org")

      described_class.call(organization: organization, website: "")

      expect(organization.reload.website_url).to eq("https://existing.org")
    end

    it "overwrites an existing website by default (latest-wins)" do
      organization.update!(website_url: "https://old.org")

      described_class.call(organization: organization, website: "https://new.org")

      expect(organization.reload.website_url).to eq("https://new.org")
    end

    it "fills a blank website but leaves an existing one when overwrite is false" do
      organization.update!(website_url: "https://curated.org")

      described_class.call(organization: organization, website: "https://new.org", overwrite: false)

      expect(organization.reload.website_url).to eq("https://curated.org")
    end

    it "fills a blank website when overwrite is false" do
      organization.update!(website_url: nil)

      described_class.call(organization: organization, website: "https://new.org", overwrite: false)

      expect(organization.reload.website_url).to eq("https://new.org")
    end
  end

  describe "agency_type" do
    it "stores a non-'Other' classification with no agency_type_other" do
      described_class.call(organization: organization, agency_type: "Government agency")

      expect(organization.reload.agency_type).to eq("Government agency")
      expect(organization.agency_type_other).to be_nil
    end

    it "folds an 'Other' answer into agency_type and the stripped free text into agency_type_other" do
      described_class.call(organization: organization, agency_type: "Other: Equine therapy")

      expect(organization.reload.agency_type).to eq("Other")
      expect(organization.agency_type_other).to eq("Equine therapy")
    end

    it "captures the 'Other' free text as an OtherResponse for the curation queue" do
      expect {
        described_class.call(organization: organization, agency_type: "Other: Equine therapy")
      }.to change { organization.other_responses.count }.by(1)

      response = organization.other_responses.last
      expect(response.field_identifier).to eq(OtherResponse::ORGANIZATION_TYPE_FIELD_IDENTIFIER)
      expect(response.text).to eq("Equine therapy")
    end

    it "clears a stale agency_type_other when the latest answer is no longer 'Other'" do
      organization.update!(agency_type: "Other", agency_type_other: "Equine therapy")

      described_class.call(organization: organization, agency_type: "Government agency")

      expect(organization.reload.agency_type).to eq("Government agency")
      expect(organization.agency_type_other).to be_nil
    end

    it "does not clobber an existing agency_type with a blank answer" do
      organization.update!(agency_type: "Government agency")

      described_class.call(organization: organization, agency_type: "")

      expect(organization.reload.agency_type).to eq("Government agency")
    end

    it "leaves an existing agency_type untouched when overwrite is false" do
      organization.update!(agency_type: "Government agency")

      described_class.call(organization: organization, agency_type: "For-profit", overwrite: false)

      expect(organization.reload.agency_type).to eq("Government agency")
    end

    it "fills a blank agency_type when overwrite is false" do
      organization.update!(agency_type: nil)

      described_class.call(organization: organization, agency_type: "For-profit", overwrite: false)

      expect(organization.reload.agency_type).to eq("For-profit")
    end
  end

  describe "the result" do
    it "reports the columns it filled" do
      organization.update!(website_url: nil, agency_type: nil)

      result = described_class.call(organization: organization, website: "acme.org", agency_type: "For-profit", overwrite: false)

      expect(result.filled).to contain_exactly("website", "type")
      expect(result.conflicts).to be_empty
    end

    it "reports conflicts for answers that differ from existing values (overwrite: false)" do
      organization.update!(website_url: "https://curated.org", agency_type: "For-profit")

      result = described_class.call(organization: organization, website: "https://new.org", agency_type: "Government agency", overwrite: false)

      expect(result.filled).to be_empty
      expect(result.conflicts.map(&:field)).to contain_exactly(:website_url, :agency_type)
    end

    it "reports no conflicts when overwriting (public flow)" do
      organization.update!(website_url: "https://curated.org", agency_type: "For-profit")

      result = described_class.call(organization: organization, website: "https://new.org", agency_type: "Government agency")

      expect(result.conflicts).to be_empty
    end
  end
end
