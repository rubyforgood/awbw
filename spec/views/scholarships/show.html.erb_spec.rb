require "rails_helper"

RSpec.describe "scholarships/show", type: :view do
  let(:allocatable) { create(:event_registration) }
  let(:scholarship) { create(:scholarship, recipient: allocatable.registrant) }

  before do
    create(:allocation, source: scholarship, allocatable:, amount: 1000)
    assign(:scholarship, scholarship)
    assign(:allocatable, allocatable)
    render
  end

  it "shows scholarship details" do
    expect(rendered).to have_content("$10.00")
    expect(rendered).to have_content("No")
    expect(rendered).to have_content(scholarship.recipient.full_name)
    expect(rendered).to have_content(allocatable.event.title)
  end

  it "links to edit page" do
    expect(rendered).to have_link("Edit scholarship", href: edit_scholarship_path(scholarship))
  end
end
