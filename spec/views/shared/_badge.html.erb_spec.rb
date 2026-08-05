require "rails_helper"

RSpec.describe "shared/_badge", type: :view do
  let(:classes) { "bg-green-50 text-green-700 border-green-200" }

  context "without an href (static pill)" do
    before do
      render partial: "shared/badge",
             locals: { label: "Paid", icon: "fa-solid fa-circle-check", classes: }
    end

    it "renders a span, not a link" do
      expect(rendered).to have_css("span.rounded-full", text: "Paid")
      expect(rendered).not_to have_css("a")
    end

    it "applies the theme classes, the static padding, and the icon" do
      expect(rendered).to have_css("span.bg-green-50.text-green-700.border-green-200.px-2\\.5")
      expect(rendered).to have_css("i.fa-circle-check")
    end
  end

  context "with an href (link pill)" do
    before do
      render partial: "shared/badge",
             locals: { label: "Paid", icon: "fa-solid fa-circle-check", classes:, href: "/somewhere" }
    end

    it "wraps the pill in a link with the wider padding" do
      expect(rendered).to have_css("a[href='/somewhere'].rounded-full.px-5", text: "Paid")
    end

    it "appends the jump icon" do
      expect(rendered).to have_css("a i.fa-arrow-up-right-from-square")
    end
  end

  it "omits the icon element when no icon is given" do
    render partial: "shared/badge", locals: { label: "Upcoming", classes: }
    expect(rendered).to have_css("span", text: "Upcoming")
    expect(rendered).not_to have_css("span > i")
  end
end
