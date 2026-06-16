require 'rails_helper'

RSpec.describe "sectors/_tagging_label", type: :view do
  let(:sector) { create(:sector, name: "Survivors") }

  it "links to taggings with sector filter" do
    render partial: "sectors/tagging_label", locals: { sector: sector }

    expect(rendered).to include("Survivors")
    expect(rendered).to include("sector_names_all=Survivors")
  end

  it "renders a plain lime chip without a star by default" do
    render partial: "sectors/tagging_label", locals: { sector: sector }

    expect(rendered).not_to include("fa-star")
    expect(rendered).to include(DomainTheme.bg_class_for(:sectors))
  end

  it "marks a primary sector with a darker-green chip and a star" do
    render partial: "sectors/tagging_label", locals: { sector: sector, is_primary: true }

    expect(rendered).to include("fa-star")
    expect(rendered).to include("bg-lime-200")
  end
end
