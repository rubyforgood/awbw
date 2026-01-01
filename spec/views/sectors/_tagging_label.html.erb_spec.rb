require 'rails_helper'

RSpec.describe "sectors/_tagging_label", type: :view do
  let(:sector) { create(:sector, name: "Survivors") }

  it "links to taggings with sector filter" do
    render partial: "sectors/tagging_label", locals: { sector: sector }

    expect(rendered).to include("Survivors")
    expect(rendered).to include("sector_names=Survivors")
  end
end
