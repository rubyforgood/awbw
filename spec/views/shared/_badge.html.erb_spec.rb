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

    it "applies the theme classes, the unified padding, and the icon" do
      expect(rendered).to have_css("span.bg-green-50.text-green-700.border-green-200.px-2")
      expect(rendered).to have_css("i.fa-circle-check")
    end
  end

  context "with an href (link pill)" do
    before do
      render partial: "shared/badge",
             locals: { label: "Paid", icon: "fa-solid fa-circle-check", classes:, href: "/somewhere" }
    end

    it "wraps the pill in a link at the unified padding" do
      expect(rendered).to have_css("a[href='/somewhere'].rounded-full.px-2", text: "Paid")
    end

    it "always appends the jump icon on a link" do
      expect(rendered).to have_css("a i.fa-arrow-up-right-from-square")
    end
  end

  it "omits the icon element when no icon is given" do
    render partial: "shared/badge", locals: { label: "Upcoming", classes: }
    expect(rendered).to have_css("span", text: "Upcoming")
    expect(rendered).not_to have_css("span > i")
  end

  it "renders a raw leading marker via icon_html" do
    render partial: "shared/badge",
           locals: { label: "Active", classes:, icon_html: '<span class="marker-dot"></span>'.html_safe }
    expect(rendered).to have_css("span.marker-dot")
  end

  it "appends extra classes to the badge element" do
    render partial: "shared/badge", locals: { label: "Built in", classes:, extra: "shrink-0" }
    expect(rendered).to have_css("span.shrink-0.rounded-full", text: "Built in")
  end
end
