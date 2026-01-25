require 'rails_helper'

RSpec.describe "workshop_ideas/edit", type: :view do
  let(:user) { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:workshop_idea) { create(:workshop_idea, created_by: user, updated_by: user) }

  before(:each) do
    assign(:workshop_idea, workshop_idea)
    allow(view).to receive(:current_user).and_return(user)
    assign(:windows_types, [])
  end


  it "renders the edit workshop_idea form" do
    render

    assert_select "form[action=?][method=?]", workshop_idea_path(workshop_idea), "post" do
      assert_select "textarea[name=?]", "workshop_idea[title]"

      assert_select "select[name=?]", "workshop_idea[windows_type_id]"

      assert_select "input[type=hidden][name=?]", "workshop_idea[rhino_tips]"

      assert_select "input[type=hidden][name=?]", "workshop_idea[rhino_objective]"

      assert_select "input[type=hidden][name=?]", "workshop_idea[rhino_materials]"

      assert_select "input[type=hidden][name=?]", "workshop_idea[rhino_introduction]"

      assert_select "input[type=hidden][name=?]", "workshop_idea[rhino_creation]"

      assert_select "input[type=hidden][name=?]", "workshop_idea[rhino_closing]"

      assert_select "input[type=hidden][name=?]", "workshop_idea[rhino_visualization]"

      assert_select "input[type=hidden][name=?]", "workshop_idea[rhino_warm_up]"

      assert_select "input[type=hidden][name=?]", "workshop_idea[rhino_opening_circle]"

      assert_select "input[type=hidden][name=?]", "workshop_idea[rhino_demonstration]"

      assert_select "input[type=hidden][name=?]", "workshop_idea[rhino_setup]"

      assert_select "input[type=hidden][name=?]", "workshop_idea[rhino_optional_materials]"

      assert_select "input[type=hidden][name=?]", "workshop_idea[rhino_notes]"
    end
  end

  context "when viewed by a regular user" do
    before { allow(view).to receive(:current_user).and_return(user) }

    it "does not show the staff_notes field" do
      render
      expect(rendered).not_to have_selector("textarea[name='workshop_idea[staff_notes]']")
    end
  end

  context "when viewed by an admin user" do
    before { allow(view).to receive(:current_user).and_return(admin) }

    it "shows the staff_notes field" do
      render
      expect(rendered).to have_selector("textarea[name='workshop_idea[staff_notes]']")
    end
  end
end
