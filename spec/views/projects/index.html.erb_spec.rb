require 'rails_helper'

RSpec.describe "projects/index", type: :view do
  before(:each) do
    assign(:projects, [
      Project.create!(
        windows_type: nil,
        name: "Name",
        description: "Description",
        project_status: 2,
        location: nil,
        district: "District",
        locality: "Locality",
        inactive: false,
        notes: "MyText"
      ),
      Project.create!(
        windows_type: nil,
        name: "Name",
        description: "Description",
        project_status: 2,
        location: nil,
        district: "District",
        locality: "Locality",
        inactive: false,
        notes: "MyText"
      )
    ])
  end

  it "renders a list of projects" do
    render
    cell_selector = 'div>p'
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Name".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Description".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(2.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
    assert_select cell_selector, text: Regexp.new("District".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("Locality".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(false.to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
  end
end
