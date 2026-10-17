require "rails_helper"

RSpec.describe "Moving and deleting a comment", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let!(:user) { create(:user, person: person) }

  before { sign_in admin }

  scenario "re-points a comment filed against the user account to the profile" do
    comment = create(:comment, commentable: user, topic: "Intake", body: "Meant for the profile.", created_by: admin)

    visit comments_and_communications_path(person_id: person.id)

    within "##{ActionView::RecordIdentifier.dom_id(comment)}" do
      click_button "Edit"
      select "Profile", from: "Logged against"
      click_button "Save"
      expect(page).to have_link("Profile")
    end

    expect(comment.reload.commentable).to eq(person)
  end

  scenario "deletes a comment after confirming" do
    comment = create(:comment, commentable: user, body: "Filed by mistake.", created_by: admin)

    visit comments_and_communications_path(person_id: person.id)

    within "##{ActionView::RecordIdentifier.dom_id(comment)}" do
      click_button "Edit"
      accept_confirm { click_link "Delete" }
    end

    expect(page).not_to have_content("Filed by mistake.")
    expect(Comment.exists?(comment.id)).to be(false)
  end

  scenario "deletes a comment from the person edit page's comments section" do
    comment = create(:comment, commentable: person, body: "Filed on the profile by mistake.", created_by: admin)

    visit edit_person_path(person)

    within "#comments-section" do
      click_button "Edit"
      accept_confirm { click_link "Delete" }
      expect(page).not_to have_content("Filed on the profile by mistake.")
    end

    expect(Comment.exists?(comment.id)).to be(false)
  end

  scenario "deletes a comment from a record form that turns Turbo off" do
    affiliation = create(:affiliation, person: person)
    comment = create(:comment, commentable: affiliation, body: "Wrong affiliation.", created_by: admin)

    visit edit_affiliation_path(affiliation)

    within "#comments-section" do
      click_button "Edit"
      accept_confirm { click_link "Delete" }
      expect(page).not_to have_content("Wrong affiliation.")
    end

    expect(Comment.exists?(comment.id)).to be(false)
  end
end
