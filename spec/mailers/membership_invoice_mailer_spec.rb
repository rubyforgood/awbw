require "rails_helper"

RSpec.describe NotificationMailer, "#membership_invoice" do
  let(:person) { create(:person, first_name: "Fay") }
  let(:membership) { create(:membership, person:) }
  let(:notification) do
    create(:notification, kind: "membership_invoice", noticeable: membership, person:,
      recipient_role: "person", recipient_email: person.user.email)
  end

  it "links to the next unpaid invoice" do
    invoice = create(:membership_invoice, membership:, start_date: Date.current,
      end_date: Date.current + Membership::INVOICE_PERIOD - 1.day, cost_cents: 10_000)

    mail = described_class.membership_invoice(notification)

    expect(mail.to).to eq([ person.user.email ])
    expect(mail.subject).to include("Your membership invoice")
    expect(mail.html_part.body.decoded).to include(membership_invoice_url(invoice))
    expect(mail.html_part.body.decoded).to include("$100")
    expect(mail.text_part.body.decoded).to include(membership_invoice_url(invoice))
  end

  it "links to the most recent invoice when none is unpaid" do
    invoice = create(:membership_invoice, :comped, membership:, start_date: Date.current,
      end_date: Date.current + Membership::INVOICE_PERIOD - 1.day)

    mail = described_class.membership_invoice(notification)

    expect(mail.html_part.body.decoded).to include(membership_invoice_url(invoice))
  end

  it "falls back to the profile when there is no invoice" do
    mail = described_class.membership_invoice(notification)

    expect(mail.html_part.body.decoded).to include(person_url(person))
  end
end
