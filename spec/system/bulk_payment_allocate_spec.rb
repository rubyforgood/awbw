require "rails_helper"

RSpec.describe "Bulk payment event card interactions", type: :system do
  let(:admin) { create(:user, :admin) }
  let(:event) { create(:event, cost_cents: 2500) }
  let(:form) { create(:form) }
  let(:payer) { create(:person, first_name: "Quentin", last_name: "Cardpayer") }
  let(:registrant) { create(:person, first_name: "Fay", last_name: "Cardpaid") }

  let!(:submission) { create(:form_submission, person: payer, form: form, event: event, role: "bulk_payment") }
  let!(:registration) { create(:event_registration, event: event, registrant: registrant, status: "registered") }
  let!(:payment) do
    create(:payment, person: payer, form_submission: submission,
           amount_cents: 5000, amount_cents_remaining: 5000)
  end

  before do
    EventForm.create!(event: event, form: form, role: "bulk_payment")
    submission.link_registration!(registration.id)
    sign_in admin
  end

  it "allocates from the inline field and updates the card in place" do
    visit bulk_payments_event_path(event, expand: submission.id)

    within("#payment-card-#{submission.id}") do
      fill_in "amount_dollars", with: "10.00"
      click_button "Allocate"

      expect(page).to have_content("$15", wait: 5)
    end

    expect(page).to have_current_path(/bulk_payments/)
    expect(payment.reload.amount_cents_remaining).to eq(4000)
  end

  # The card's links live inside the bulk_payments_results turbo frame; they must
  # break out to a full-page load, not try to render their frame-less
  # destinations inside the frame (which 500s into the "Oopsie!" box).
  it "navigates the whole page when a card link is clicked, without Oopsie" do
    visit bulk_payments_event_path(event, expand: submission.id)

    within("#payment-card-#{submission.id}") { click_link "Submission - ID: #{submission.id}" }

    expect(page).to have_current_path(/bulk_payment/)
    expect(page).not_to have_content("Oopsie!")
  end

  it "unlinks a registration in place" do
    visit bulk_payments_event_path(event, expand: submission.id)

    within("#payment-card-#{submission.id}") do
      click_button "Unlink"
      expect(page).to have_no_button("Unlink", wait: 5)
    end

    expect(page).not_to have_content("Oopsie!")
    expect(submission.reload.linked_registration_ids).to be_empty
  end
end
