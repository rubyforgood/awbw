require "rails_helper"

RSpec.describe EventRegistrationImporter::Columns do
  describe "TEMPLATE_HEADERS" do
    it "offers one spelling for every column the importer reads" do
      fields = described_class::TEMPLATE_HEADERS.map { |header| described_class.field_for(header) }

      expect(fields).to all(be_present)
      expect(fields.tally.select { |_field, count| count > 1 }).to be_empty
      expect(described_class::HEADER_ALIASES.keys - fields).to be_empty
    end
  end
end
