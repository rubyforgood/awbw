require "rails_helper"

RSpec.describe "PayChargeExtensions dedupe", type: :model do
  it "does not create a second payment for an existing Stripe charge" do
    person = create(:person)
    ExternalProcessorPayment.create!(
      stripe_charge_id: "ch_existing",
      person: person,
      amount_cents: 1_000,
      amount_cents_remaining: 1_000,
      currency: "usd",
      skip_pay_charge_validation: true
    )

    expect {
      create(:pay_charge, processor_id: "ch_existing", metadata: { "person_id" => person.id })
    }.not_to change(ExternalProcessorPayment, :count)
  end
end
