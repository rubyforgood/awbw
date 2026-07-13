require "rails_helper"

RSpec.describe "workshop_variations/index", type: :view do
  let(:admin) { create(:user, super_user: true) }
  let(:variation1) { create(:workshop_variation, name: "Alpha variation") }
  let(:variation2) { create(:workshop_variation, name: "Bravo variation") }

  before(:each) do
    sign_in admin
    allow(view).to receive(:turbo_frame_request?).and_return(true)
    assign(:workshop_variations,
           WorkshopVariationDecorator.decorate_collection(paginated([ variation1, variation2 ])))
  end

  it "renders a list of workshop variations" do
    render template: "workshop_variations/workshop_variations_results"
    expect(rendered).to include(variation1.name, variation2.name)
  end

  it "renders sortable column headers" do
    render template: "workshop_variations/workshop_variations_results"
    expect(rendered).to include("sort=name", "sort=author", "sort=updated_at")
  end

  it "renders a friendly message when no workshop variations exist" do
    assign(:workshop_variations, paginated([]))
    render template: "workshop_variations/workshop_variations_results"
    expect(rendered).to match(/No workshop variations found/)
  end
end
