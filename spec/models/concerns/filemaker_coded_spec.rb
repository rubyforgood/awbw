require "rails_helper"

RSpec.describe FilemakerCoded do
  describe ".with_filemaker_code" do
    it "matches a code anywhere in the list, however it's spaced" do
      single = create(:person, filemaker_code: "00006")
      listed = create(:person, filemaker_code: "00012,00006")
      spaced = create(:person, filemaker_code: "00012 , 00006")
      create(:person, filemaker_code: "000066")
      create(:person, filemaker_code: nil)

      expect(Person.with_filemaker_code(" 00006 ")).to contain_exactly(single, listed, spaced)
    end
  end

  describe ".filemaker_archives" do
    it "names the archive tables each coded model points into" do
      expect(Person.filemaker_archives).to eq([ FmRolodex ])
      expect(Organization.filemaker_archives).to eq([ FmProject ])
    end
  end
end
