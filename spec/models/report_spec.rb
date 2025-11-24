require "rails_helper"

RSpec.describe Report do
  describe "associations" do
    it { should belong_to(:user) }
    it { should belong_to(:project) }
    it { should belong_to(:windows_type) }
    it { should belong_to(:owner).optional }
    it { should have_one(:form) }
    it { should have_one(:main_image) }
    it { should have_many(:gallery_images) }
    it { should have_many(:form_fields).through(:form) }
    it { should have_many(:report_form_field_answers).dependent(:destroy) }
    it { should have_many(:quotable_item_quotes).dependent(:destroy) }
    it { should have_many(:quotes).through(:quotable_item_quotes).dependent(:destroy) }
    it { should have_many(:notifications).dependent(:destroy) }
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
end

