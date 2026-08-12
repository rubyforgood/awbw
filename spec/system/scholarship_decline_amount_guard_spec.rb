require "rails_helper"

# The admin edit form warns before saving an amount change on a scholarship the
# recipient has declined, because changing the amount re-offers the award and
# clears the recorded decline (date + reason) and re-funds the allocation.
RSpec.describe "Scholarship decline amount-change warning", type: :system do
  let(:admin) { create(:user, :admin) }
  let!(:admin_person) { create(:person, user: admin) }
  let(:event) { create(:event, cost_cents: 10_000) }
  let(:registration) { create(:event_registration, event:) }
  let(:scholarship) { create(:scholarship, recipient: registration.registrant, amount_cents: 5_000) }
  let!(:allocation) { create(:allocation, source: scholarship, allocatable: registration, amount: 5_000) }

  before do
    driven_by(:selenium_chrome_headless)
    scholarship.reload.decline_agreement!("Timing no longer works")
    sign_in admin
  end

  it "warns and, when confirmed, saves the new amount and clears the decline" do
    visit edit_scholarship_path(scholarship)
    fill_in "scholarship_amount_dollars", with: "75"

    accept_confirm(/declined the scholarship/) do
      find("[type='submit']").click
    end

    expect(page).to have_text("Scholarship updated.", wait: 10)
    scholarship.reload
    expect(scholarship.amount_cents).to eq(7_500)
    expect(scholarship.agreement_declined?).to be(false)
  end

  it "cancels the save when the warning is dismissed, preserving the decline" do
    visit edit_scholarship_path(scholarship)
    fill_in "scholarship_amount_dollars", with: "75"

    dismiss_confirm(/declined the scholarship/) do
      find("[type='submit']").click
    end

    expect(page).to have_css("[type='submit']", wait: 5) # still on the edit form
    scholarship.reload
    expect(scholarship.amount_cents).to eq(5_000)
    expect(scholarship.agreement_declined?).to be(true)
  end

  it "does not warn when the amount is left unchanged" do
    visit edit_scholarship_path(scholarship)
    find("[type='submit']").click

    expect(page).to have_text("Scholarship updated.", wait: 10)
    expect(scholarship.reload.agreement_declined?).to be(true)
  end
end
