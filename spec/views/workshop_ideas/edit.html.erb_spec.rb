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

      assert_select "textarea[name=?]", "workshop_idea[description]"

      assert_select "select[name=?]", "workshop_idea[windows_type_id]"

      assert_select "textarea[name=?]", "workshop_idea[tips]"

      assert_select "textarea[name=?]", "workshop_idea[objective]"

      assert_select "textarea[name=?]", "workshop_idea[materials]"

      assert_select "textarea[name=?]", "workshop_idea[introduction]"

      assert_select "textarea[name=?]", "workshop_idea[creation]"

      assert_select "textarea[name=?]", "workshop_idea[closing]"

      # assert_select "textarea[name=?]", "workshop_idea[visualization]"

      assert_select "textarea[name=?]", "workshop_idea[warm_up]"

      assert_select "textarea[name=?]", "workshop_idea[opening_circle]"

      assert_select "textarea[name=?]", "workshop_idea[demonstration]"

      assert_select "textarea[name=?]", "workshop_idea[setup]"

      # assert_select "textarea[name=?]", "workshop_idea[instructions]"

      assert_select "textarea[name=?]", "workshop_idea[optional_materials]"

      assert_select "textarea[name=?]", "workshop_idea[notes]"
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
