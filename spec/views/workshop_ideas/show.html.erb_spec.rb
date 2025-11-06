require 'rails_helper'

RSpec.describe "workshop_ideas/show", type: :view do
  before(:each) do
    assign(:workshop_idea, WorkshopIdea.create!(
      title: "Title",
      description: "MyText",
      staff_notes: "MyText",
      created_by: nil,
      windows_type_id: nil,
      tips: "MyText",
      objective: "MyText",
      materials: "MyText",
      introduction: "MyText",
      creation: "MyText",
      closing: "MyText",
      visualization: "MyText",
      warm_up: "MyText",
      opening_circle: "MyText",
      demonstration: "MyText",
      setup: "MyText",
      instructions: "MyText",
      optional_materials: "MyText",
      notes: "MyText"
    ))
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Title/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(//)
    expect(rendered).to match(//)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
    expect(rendered).to match(/MyText/)
  end
end
