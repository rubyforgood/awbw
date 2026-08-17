require "rails_helper"

RSpec.describe Report do
  describe "associations" do
    it { should belong_to(:created_by) }
    it { should belong_to(:organization) }
    it { should belong_to(:windows_type) }
    it { should belong_to(:owner).optional }
    it { should have_one(:form) }
    it { should have_one(:primary_asset) }
    it { should have_many(:gallery_assets) }
    it { should have_many(:form_fields).through(:form) }
    it { should have_many(:report_form_field_answers).dependent(:destroy) }
    it { should have_many(:quotable_item_quotes).dependent(:nullify) }
    it { should have_many(:quotes).through(:all_quotable_item_quotes).dependent(:nullify) }
    it { should have_many(:notifications).dependent(:nullify) }
    it { should have_many(:sectorable_items).dependent(:destroy) }
    it { should have_many(:sectors).through(:sectorable_items).dependent(:destroy) }
    it { should have_many(:media_files).dependent(:destroy) }

    it { should accept_nested_attributes_for(:media_files) }
    it { should accept_nested_attributes_for(:report_form_field_answers) }
    it { should accept_nested_attributes_for(:quotable_item_quotes) }
  end

  describe "validations" do
    it { should validate_content_type_of(:form_file).allowing(Report::FORM_FILE_CONTENT_TYPES) }
    it { should validate_content_type_of(:form_file).rejecting("text/plain", "text/xml") }
  end

  describe "#set_has_attachment" do
    let(:report) { create(:report) }

    it "sets has_attachment when an image is attached" do
      report.image.attach(
        io: Rails.root.join("spec/fixtures/files/sample.png").open,
        filename: "sample.png",
        content_type: "image/png"
      )
      report.save!

      expect(report.has_attachment).to be(true)
    end

    it "leaves has_attachment false with no attachments" do
      report.save!

      expect(report.has_attachment).to be(false)
    end
  end
end
