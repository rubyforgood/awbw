require "rails_helper"

RSpec.describe "Payment comments & communications section", type: :system, js: true do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }
  let!(:payment) { create(:payment, person:) }

  before { sign_in admin }

  it "adds a comment from the top slot" do
    visit payment_path(payment)

    click_on "Add comment"
    expect(page).to have_css("textarea[name='comment[body]']")

    find("textarea[name='comment[body]']").set("Added from the slot")
    click_on "Save"

    expect(page).to have_text("Added from the slot")
    expect(page).to have_link("Add comment")
    expect(page).to have_link("Add communication")
  end

  it "cancels the new comment form" do
    visit payment_path(payment)

    click_on "Add comment"
    expect(page).to have_css("textarea[name='comment[body]']")

    click_on "Cancel"

    expect(page).not_to have_css("textarea[name='comment[body]']")
    expect(page).to have_link("Add comment")
  end

  it "edits a comment inline" do
    comment = create(:comment, commentable: payment, body: "Original")

    visit payment_path(payment)

    within("#comment_#{comment.id}") { click_on "Edit" }
    expect(page).to have_css("textarea[name='comment[body]']")

    find("textarea[name='comment[body]']").set("Updated inline")
    click_on "Save"

    expect(page).to have_text("Updated inline")
    within("#comment_#{comment.id}") { expect(page).to have_link("Edit") }
  end
end
