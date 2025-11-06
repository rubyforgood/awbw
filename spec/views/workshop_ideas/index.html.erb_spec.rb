require 'rails_helper'

RSpec.describe "workshop_ideas/index", type: :view do
  before(:each) do
    assign(:workshop_ideas, [
      WorkshopIdea.create!(
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
      ),
      WorkshopIdea.create!(
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
      )
    ])
  end

  it "renders a list of workshop_ideas" do
    render
    cell_selector = 'div>p'
    assert_select cell_selector, text: Regexp.new("Title".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
    assert_select cell_selector, text: Regexp.new(nil.to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
    assert_select cell_selector, text: Regexp.new("MyText".to_s), count: 2
  end
end
