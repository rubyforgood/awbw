require "rails_helper"

RSpec.describe OrganizationServices::AutofillChange do
  def change(**overrides)
    described_class.new(**{ field: "website_url", label: "Website", value: "https://helpinghands.org" }.merge(overrides))
  end

  describe "#description" do
    it "is the label alone for a field on the org itself" do
      expect(change.description).to eq("Website")
    end

    it "names the address when the field belongs to one" do
      scoped = change(field: "zip_code", label: "ZIP", value: "78701", scope: "Austin work address")

      expect(scoped.description).to eq("ZIP on the Austin work address")
    end
  end

  describe "round-tripping through the JSON column" do
    it "restores every part of the change" do
      original = change(field: "zip_code", label: "ZIP", value: "78701", scope: "Austin work address")

      restored = described_class.from_json(original.to_json_hash)

      expect(restored).to eq(original)
    end

    # The column is JSON, so keys come back as strings after a round trip through
    # the database but as symbols when a caller builds one by hand.
    it "accepts symbol keys" do
      restored = described_class.from_json(field: "agency_type", label: "Type", value: "For-profit")

      expect(restored).to have_attributes(field: "agency_type", value: "For-profit")
    end

    it "omits a nil scope rather than storing it" do
      expect(change.to_json_hash).not_to have_key("scope")
    end

    # A display aid should degrade rather than break a page load.
    it "drops an entry with no field" do
      expect(described_class.from_json("label" => "Website")).to be_nil
      expect(described_class.all_from_json([ { "label" => "Website" }, nil ])).to eq([])
    end

    it "falls back to the field when an entry has no label" do
      expect(described_class.from_json("field" => "website_url").label).to eq("website_url")
    end
  end

  describe "#key" do
    it "distinguishes the same field on two different addresses" do
      austin = change(field: "zip_code", label: "ZIP", value: "78701", scope: "Austin work address")
      reno = change(field: "zip_code", label: "ZIP", value: "89501", scope: "Reno work address")

      expect(austin.key).not_to eq(reno.key)
    end

    it "matches the same field regardless of the value written" do
      expect(change(value: "https://a.org").key).to eq(change(value: "https://b.org").key)
    end
  end
end
