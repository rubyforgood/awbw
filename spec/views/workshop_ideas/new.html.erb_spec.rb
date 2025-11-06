require 'rails_helper'

RSpec.describe "workshop_ideas/new", type: :view do
  before(:each) do
    assign(:workshop_idea, WorkshopIdea.new(
      title: "MyString",
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

  it "renders new workshop_idea form" do
    render

    assert_select "form[action=?][method=?]", workshop_ideas_path, "post" do

      assert_select "input[name=?]", "workshop_idea[title]"

      assert_select "textarea[name=?]", "workshop_idea[description]"

      assert_select "textarea[name=?]", "workshop_idea[staff_notes]"

      assert_select "input[name=?]", "workshop_idea[created_by_id]"

      assert_select "input[name=?]", "workshop_idea[windows_type_id_id]"

      assert_select "textarea[name=?]", "workshop_idea[tips]"

      assert_select "textarea[name=?]", "workshop_idea[objective]"

      assert_select "textarea[name=?]", "workshop_idea[materials]"

      assert_select "textarea[name=?]", "workshop_idea[introduction]"

      assert_select "textarea[name=?]", "workshop_idea[creation]"

      assert_select "textarea[name=?]", "workshop_idea[closing]"

      assert_select "textarea[name=?]", "workshop_idea[visualization]"

      assert_select "textarea[name=?]", "workshop_idea[warm_up]"

      assert_select "textarea[name=?]", "workshop_idea[opening_circle]"

      assert_select "textarea[name=?]", "workshop_idea[demonstration]"

      assert_select "textarea[name=?]", "workshop_idea[setup]"

      assert_select "textarea[name=?]", "workshop_idea[instructions]"

      assert_select "textarea[name=?]", "workshop_idea[optional_materials]"

      assert_select "textarea[name=?]", "workshop_idea[notes]"
    end
  end
end
