require 'rails_helper'

RSpec.describe "workshop_ideas/edit", type: :view do
  let(:workshop_idea) {
    WorkshopIdea.create!(
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
    )
  }

  before(:each) do
    assign(:workshop_idea, workshop_idea)
  end

  it "renders the edit workshop_idea form" do
    render

    assert_select "form[action=?][method=?]", workshop_idea_path(workshop_idea), "post" do

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
