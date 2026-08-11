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

      expect(result.changes.map(&:label)).to contain_exactly("Website", "Type")
    end

    # A returning registrant resubmitting what's already on file changed nothing,
    # and the linking page's "filled from the form" note must not claim otherwise.
    # Filling a blank and overwriting a curated value are different facts about the
    # org, and only the second one loses something an admin may want back.
    it "marks a filled blank as new, carrying no previous value" do
      organization.update!(website_url: nil)

      result = described_class.call(organization: organization, website: "helpinghands.org")

      expect(result.changes.first).to have_attributes(change_type: "new", previous_value: nil, value: "helpinghands.org")
    end

    it "marks a replaced value as an update, carrying what it displaced" do
      organization.update!(website_url: "https://curated.org")

      result = described_class.call(organization: organization, website: "helpinghands.org")

      expect(result.changes.first).to have_attributes(
        change_type: "update", previous_value: "https://curated.org", value: "helpinghands.org"
      )
    end

    it "reports nothing filled when the answers match what is already stored" do
      organization.update!(website_url: "https://curated.org", agency_type: "For-profit")

      result = described_class.call(organization: organization, website: "https://curated.org", agency_type: "For-profit")

      expect(result.changes).to be_empty
    end

    it "reports nothing filled when the blanks were left as conflicts" do
      organization.update!(website_url: "https://curated.org", agency_type: "For-profit")

      result = described_class.call(organization: organization, website: "https://new.org", agency_type: "Government agency", overwrite: false)

      expect(result.changes).to be_empty
    end
  end
end
