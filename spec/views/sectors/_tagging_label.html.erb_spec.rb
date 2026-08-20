require 'rails_helper'

RSpec.describe "sectors/_tagging_label", type: :view do
  let(:sector) { create(:sector, :published, name: "Survivors") }

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

  it "marks a primary sector with a light-green chip and a star" do
    render partial: "sectors/tagging_label", locals: { sector: sector, is_primary: true }

    expect(rendered).to include("fa-star")
    expect(rendered).to include("bg-lime-100")
  end

  context "when the sector is hidden from the public (unpublished)" do
    let(:sector) { create(:sector, :unpublished, name: "Survivors") }

    it "renders a muted grey chip with the closed-eye hidden icon" do
      render partial: "sectors/tagging_label", locals: { sector: sector }

      expect(rendered).to include("Hidden from the public")
      expect(rendered).to include("bg-gray-100")
      expect(rendered).not_to include(DomainTheme.bg_class_for(:sectors))
    end

    it "keeps the grey treatment even when passed an explicit background colour" do
      render partial: "sectors/tagging_label", locals: { sector: sector, bg_color: "bg-white" }

      expect(rendered).to include("bg-gray-100")
      expect(rendered).not_to include("bg-white")
    end
  end
end
