require "rails_helper"

RSpec.describe "New comment composer on the global comments index", type: :system do
  let(:admin) { create(:user, :admin) }

  # Sets the TomSelect value directly instead of typing into it, so the spec
  # doesn't depend on a live /search/commentable fetch completing in time —
  # same pattern person_saves_workshop_log_spec.rb uses for its workshop picker.
  def select_tom_select_option(hidden_select_id, value, label)
    page.execute_script(<<~JS)
      var el = document.getElementById('#{hidden_select_id}');
      var ts = el.tomselect;
      ts.addOption({id: '#{value}', label: '#{label}'});
      ts.setValue('#{value}');
    JS
  end

  it "creates a comment against an affiliation, which has no nested comments route" do
    affiliation = create(:affiliation, person: create(:person, first_name: "Fiona", last_name: "Facilitator"))

    sign_in admin
    visit comments_path

    click_button "New comment"
    select_tom_select_option("commentable_sgid", affiliation.to_sgid.to_s,
      "#{affiliation.person.full_name} @ #{affiliation.organization.name}")
    fill_in "comment_body", with: "Great facilitator, ended affiliation on good terms."
    click_button "Add comment"

    expect(page).to have_content("Great facilitator, ended affiliation on good terms.")
  end
end
