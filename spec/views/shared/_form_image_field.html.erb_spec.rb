require "rails_helper"

RSpec.describe "shared/_form_image_field", type: :view do
  let(:asset) { create(:primary_asset, :with_file) }
  let(:builder) { SimpleForm::FormBuilder.new(:primary_asset, asset, view, {}) }

  before do
    render partial: "shared/form_image_field", locals: { f: builder, label: "Primary" }
  end

  it "opens the image preview in a new tab so editors don't lose unsaved work" do
    expect(rendered).to have_css("a[target='_blank'][rel='noopener noreferrer'].cursor-zoom-in img[alt='Primary']")
  end

  it "opens the filename download link in a new tab too, with the same zoom cursor" do
    expect(rendered).to have_css("a[target='_blank'][rel='noopener noreferrer'].cursor-zoom-in", text: "missing.png")
  end
end
