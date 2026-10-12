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

    it "ignores tabs, line breaks, and non-breaking spaces stored in the list" do
      messy = create(:person)
      messy.update_columns(filemaker_code: "00012,\t00006\u00A0\n")

      expect(Person.with_filemaker_code("00006")).to contain_exactly(messy)
    end
  end

  describe "#filemaker_codes" do
    it "splits on commas only, dropping every kind of whitespace" do
      person = build(:person)
      person.filemaker_code = " 00006\t,\n00012\u00A0, ,00006"

      expect(person.filemaker_codes).to eq(%w[00006 00012])
    end

    it "keeps a list joined by another separator as one code" do
      expect(build(:person, filemaker_code: "00006; 00012").filemaker_codes).to eq([ "00006;00012" ])
    end
  end

  describe "saving" do
    it "stores the codes as a sorted, comma-space list" do
      person = create(:person, filemaker_code: "00012 ,\t00006,00012\n")

      expect(person.reload.filemaker_code).to eq("00006, 00012")
    end

    it "stores nil for a blank list" do
      expect(create(:person, filemaker_code: " , \t").reload.filemaker_code).to be_nil
    end
  end

  describe ".filemaker_archives" do
    it "names the archive tables each coded model points into" do
      expect(Person.filemaker_archives).to eq([ FmRolodex ])
      expect(Organization.filemaker_archives).to eq([ FmProject ])
    end
  end
end
