require 'rails_helper'

RSpec.describe "sectors/_tagging_label", type: :view do
  let(:sector) { create(:sector, name: "Survivors") }

  it "links to taggings with sector filter" do
    render partial: "sectors/tagging_label", locals: { sector: sector }

    expect(rendered).to include("Survivors")
    expect(rendered).to include("sector_names_all=Survivors")
  end

  context "when spanish is true" do
    it "shows Spanish name when present" do
      sector.update!(name_spanish: "Sobrevivientes")

      render partial: "sectors/tagging_label",
             locals: { sector: sector, spanish: true }

      expect(rendered).to include("Sobrevivientes")
      expect(rendered).not_to include(">Survivors<")
    end

    it "falls back to English name when Spanish name is blank" do
      render partial: "sectors/tagging_label",
             locals: { sector: sector, spanish: true }

      expect(rendered).to include("Survivors")
    end
  end
end
