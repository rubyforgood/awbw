require "rails_helper"

RSpec.describe ScholarshipMailer, type: :mailer do
  describe "#additional_support_requested_fyi" do
    let(:event) { create(:event, cost_cents: 10_000, title: "Healing Circle Training") }
    let(:registration) { create(:event_registration, event:) }
    let(:scholarship) { create(:scholarship, recipient: registration.registrant, amount_cents: 5_000) }
    let(:mail) { described_class.additional_support_requested_fyi(scholarship) }

    before do
      create(:allocation, source: scholarship, allocatable: registration, amount: 5_000)
      scholarship.reload.request_additional_support!(contribution_cents: 12_000, reason: "Employer can help")
    end

    it "renders without raising" do
      expect { mail.deliver_now }.not_to raise_error
    end

    it "sends to the trainings/programs team" do
      expect(mail.to).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
    end

    it "names the recipient in the subject" do
      expect(mail.subject).to include(scholarship.recipient.full_name)
      expect(mail.subject).to include("Additional scholarship support requested")
    end

    it "shows the contribution amount and note in the body" do
      body = mail.body.encoded
      expect(body).to include("$120")
      expect(body).to include("Employer can help")
    end
  end
end
