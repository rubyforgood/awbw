require "rails_helper"

RSpec.describe BulkPaymentReminderRecipients do
  let(:event) { create(:event, cost_cents: 10_000) }

  # Builds a bulk-payment submission whose attendees are the given hashes.
  def bulk_submission(attendees, payer: create(:person))
    form = create(:form)
    submission = create(:form_submission, form: form, event: event, person: payer, role: "bulk_payment")
    field = create(:form_field, form: form, field_identifier: "bulk_payment_attendees", name: "Attendees")
    submission.form_answers.create!(form_field: field, submitted_answer: attendees.to_json)
    submission
  end

  # A registration for a person with the given name so attendees match by name.
  def registration_for(first, last)
    create(:event_registration, event: event, registrant: create(:person, first_name: first, last_name: last))
  end

  def pay_in_full(registration)
    create(:allocation, allocatable: registration, amount: event.cost_cents)
  end

  it "includes a submitter whose attendee isn't connected to a registration" do
    bulk_submission([ { "first_name" => "Nora", "last_name" => "West" } ])

    recipients = described_class.new(event).call

    expect(recipients.size).to eq(1)
    expect(recipients.first.unregistered_count).to eq(1)
    expect(recipients.first.unpaid_count).to eq(0)
  end

  it "includes a submitter whose matched registration hasn't been paid in full" do
    registration_for("Jane", "Adams")
    bulk_submission([ { "first_name" => "Jane", "last_name" => "Adams" } ])

    recipients = described_class.new(event).call

    expect(recipients.size).to eq(1)
    expect(recipients.first.unregistered_count).to eq(0)
    expect(recipients.first.unpaid_count).to eq(1)
  end

  it "excludes a submitter whose attendees are all registered and paid" do
    paid = registration_for("Jane", "Adams")
    pay_in_full(paid)
    bulk_submission([ { "first_name" => "Jane", "last_name" => "Adams" } ])

    expect(described_class.new(event).call).to be_empty
  end

  it "counts both unregistered and unpaid attendees on one submission" do
    unpaid_reg = registration_for("Jane", "Adams")
    paid_reg = registration_for("Sam", "Cole")
    pay_in_full(paid_reg)
    bulk_submission([
      { "first_name" => "Jane", "last_name" => "Adams" },  # matched, unpaid
      { "first_name" => "Sam", "last_name" => "Cole" },     # matched, paid
      { "first_name" => "Nora", "last_name" => "West" }     # unregistered
    ])

    recipient = described_class.new(event).call.first
    expect(recipient.unregistered_count).to eq(1)
    expect(recipient.unpaid_count).to eq(1)
    expect(recipient.attendee_count).to eq(3)
    expect(recipient.outstanding_count).to eq(2)
  end

  it "skips a submission with no payer email" do
    payer = create(:person, user: nil, email: nil, email_2: nil)
    bulk_submission([ { "first_name" => "Nora", "last_name" => "West" } ], payer: payer)

    expect(described_class.new(event).call).to be_empty
  end

  it "ignores non-bulk-payment submissions" do
    create(:form_submission, event: event, role: "registration")

    expect(described_class.new(event).call).to be_empty
  end
end
