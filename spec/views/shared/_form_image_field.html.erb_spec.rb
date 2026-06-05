require "rails_helper"

RSpec.describe "shared/_form_image_field", type: :view do
  let(:asset) { create(:gallery_asset, :with_file) }
  let(:builder) { ActionView::Helpers::FormBuilder.new(:gallery_asset, asset, view, {}) }

  before do
    render partial: "shared/form_image_field", locals: { f: builder, label: "Gallery 1" }
  end

  it "links the attached file's name so it opens in a new tab" do
    expect(rendered).to have_css("a[href][target='_blank'][rel='noopener']", text: asset.file.filename.to_s)
  end
end
