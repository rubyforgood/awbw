require "rails_helper"

RSpec.describe FmArchive do
  describe "#name" do
    it "names a person by their full name" do
      rolodex = FmRolodex.new(fm_id: "00006", data: { "FirstName" => "Archie", "LastName" => " Coded " })

      expect(rolodex.name).to eq("Archie Coded")
    end

    it "names an agency rolodex record by its organization" do
      agency = FmRolodex.new(fm_id: "00006", data: { "FirstName" => "", "Organization" => "Sunrise Shelter" })

      expect(agency.name).to eq("Sunrise Shelter (agency)")
    end

    it "tells an art purchase apart from the artwork by its price" do
      purchase = FmArtPurchase.new(fm_id: "1", data: { "ArtTitle" => "After the Rain", "AmountPaid" => "$1,250.00" })
      artwork = FmArtRegistry.new(fm_id: "2", data: { "ArtTitle" => "After the Rain" })

      expect(purchase.name).to eq("After the Rain — purchased for $1,250")
      expect(artwork.name).to eq("After the Rain")
    end

    it "words the detail alone when the subject is blank" do
      expect(FmArtPurchase.new(fm_id: "1", data: { "AmountPaid" => "90" }).name).to eq("Purchased for $90")
    end

    it "falls back to the FM ID when nothing names the record" do
      expect(FmRolodex.new(fm_id: "00006", data: {}).name).to eq("00006")
    end

    it "gives every seeded archive record its own name, though the seed reuses people and art across tables" do
      expect { load Rails.root.join("db/seeds/dev/fm_archive.rb") }.to output.to_stdout

      names = FmArchivesController::TABLES.values.flat_map { |config| config[:model].all.map(&:name) }

      expect(names.tally.select { |_, count| count > 1 }.keys).to be_empty
    end
  end
end
