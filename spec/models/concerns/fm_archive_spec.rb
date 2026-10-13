require "rails_helper"

RSpec.describe FmArchive do
  describe "#name" do
    it "joins a record's name parts" do
      rolodex = FmRolodex.new(fm_id: "00006", data: { "FirstName" => "Archie", "LastName" => " Coded " })

      expect(rolodex.name).to eq("Archie Coded")
    end

    it "falls back to the next name field when the first is blank" do
      agency = FmRolodex.new(fm_id: "00006", data: { "FirstName" => "", "Organization" => "Sunrise Shelter" })

      expect(agency.name).to eq("Sunrise Shelter")
    end

    it "falls back to the FM ID when no name field is filled" do
      expect(FmRolodex.new(fm_id: "00006", data: {}).name).to eq("00006")
    end

    it "falls back to the FM ID for tables without name fields" do
      expect(FmContact.new(fm_id: "C1", data: { "Notes" => "Main contact" }).name).to eq("C1")
    end

    it "names every archive table's records from fields it documents" do
      FmArchivesController::TABLES.each_value do |config|
        model = config[:model]
        source = File.read(Rails.root.join("app/models/#{model.name.underscore}.rb"))

        model::FM_NAME_FIELDS.flatten.each do |field|
          expect(source).to match(/^#\s+#{Regexp.escape(field)}\b/), "#{model} names records by undocumented field #{field}"
        end
      end
    end
  end
end
