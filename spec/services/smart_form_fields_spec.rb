require "rails_helper"

RSpec.describe SmartFormFields do
  describe ".groups" do
    it "gives every field an identifier, a question, and an effect" do
      fields = described_class.groups.flat_map(&:fields)

      expect(fields).to be_present
      expect(fields.map(&:identifier)).to all(be_present)
      expect(fields.map(&:question)).to all(be_present)
      expect(fields.map(&:effect)).to all(be_present)
    end

    it "documents each identifier exactly once" do
      identifiers = described_class.identifiers

      expect(identifiers).to eq(identifiers.uniq)
    end
  end

  # The page's whole value is being true about what the app does, so it has to
  # fail when the app grows an identifier the page doesn't mention. The question
  # library is the list of identifiers an admin can actually end up with.
  describe "coverage of the question library" do
    it "documents every identifier the form builder can seed" do
      seeded = FormBuilderService::SECTION_FIELD_IDENTIFIERS.values.flatten.uniq
      documented = described_class.identifiers + described_class::ANSWER_ONLY_IDENTIFIERS

      expect(seeded - documented).to be_empty
    end

    it "documents every identifier the models special-case" do
      special_cased = (
        FormField::SECTOR_FIELD_IDENTIFIERS +
        FormField::AGE_GROUP_FIELD_IDENTIFIERS +
        FormField::EMAIL_FIELD_IDENTIFIERS +
        [ FormField::PAYMENT_METHOD_FIELD_IDENTIFIER, OtherResponse::ORGANIZATION_TYPE_FIELD_IDENTIFIER ]
      ).uniq
      documented = described_class.identifiers + described_class::ANSWER_ONLY_IDENTIFIERS

      expect(special_cased - documented).to be_empty
    end

    it "documents every identifier the registration pipeline reads" do
      source = Rails.root.join("app/services/event_registration_services/public_registration.rb").read
      read_identifiers = source.scan(/field_value\("([a-z0-9_]+)"\)/).flatten.uniq
      documented = described_class.identifiers + described_class::ANSWER_ONLY_IDENTIFIERS

      # Guards the guard: a regex that stopped matching would pass vacuously.
      expect(read_identifiers.size).to be > 20
      expect(read_identifiers - documented).to be_empty
    end
  end
end
