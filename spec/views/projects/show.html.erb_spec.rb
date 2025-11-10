require 'rails_helper'

RSpec.describe "projects/show", type: :view do
  before(:each) do
    assign(:project, Project.create!(
      windows_type: nil,
      name: "Name",
      description: "Description",
      project_status: 2,
      location: nil,
      district: "District",
      locality: "Locality",
      inactive: false,
      notes: "MyText"
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(//)
    expect(rendered).to match(/Name/)
    expect(rendered).to match(/Description/)
    expect(rendered).to match(/2/)
    expect(rendered).to match(//)
    expect(rendered).to match(/District/)
    expect(rendered).to match(/Locality/)
    expect(rendered).to match(/false/)
    expect(rendered).to match(/MyText/)
  end
end
