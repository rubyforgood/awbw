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

  describe "#declined_fyi" do
    let(:registration) { create(:event_registration, event: create(:event, title: "Healing Circle Training")) }
    let(:scholarship) { create(:scholarship, recipient: registration.registrant, amount_cents: 5_000) }
    let(:mail) { described_class.declined_fyi(scholarship) }

    before { scholarship.reload.decline_agreement!("Timing no longer works") }

    it "renders without raising and sends to the trainings/programs team" do
      expect { mail.deliver_now }.not_to raise_error
      expect(mail.to).to eq([ ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ])
    end

    it "names the recipient and the decline in the subject, with the reason in the body" do
      expect(mail.subject).to include("Scholarship declined")
      expect(mail.subject).to include(scholarship.recipient.full_name)
      expect(mail.body.encoded).to include("Timing no longer works")
    end
  end

  describe "#accepted_fyi" do
    let(:registration) { create(:event_registration, event: create(:event, title: "Healing Circle Training")) }
    let(:scholarship) { create(:scholarship, recipient: registration.registrant, amount_cents: 5_000) }
    let(:mail) { described_class.accepted_fyi(scholarship) }

    before { scholarship.reload.accept_agreement! }

    it "renders without raising and names the acceptance in the subject" do
      expect { mail.deliver_now }.not_to raise_error
      expect(mail.subject).to include("Scholarship accepted")
      expect(mail.subject).to include(scholarship.recipient.full_name)
    end

    context "when the scholarship is funded by a grant" do
      let(:funder) { create(:organization, name: "Acme Foundation") }
      let(:grant) { create(:grant, name: "Spring 2026 Fund", funder:) }
      let(:scholarship) { create(:scholarship, recipient: registration.registrant, amount_cents: 5_000, grant:) }

      it "shows the grant and its funder in the body" do
        body = mail.body.encoded
        expect(body).to include("Spring 2026 Fund")
        expect(body).to include("Acme Foundation")
      end
    end
  end

  describe "#accepted_confirmation" do
    let(:event) { create(:event, cost_cents: 10_000, title: "Healing Circle Training") }
    let(:registration) { create(:event_registration, event:) }
    let(:scholarship) { create(:scholarship, recipient: registration.registrant, amount_cents: 5_000) }
    let(:mail) { described_class.accepted_confirmation(scholarship) }

    before do
      create(:allocation, source: scholarship, allocatable: registration, amount: 5_000)
      scholarship.reload.accept_agreement!
    end

    it "renders without raising" do
      expect { mail.deliver_now }.not_to raise_error
    end

    it "sends to the recipient, not the trainings/programs team" do
      expect(mail.to).to eq([ scholarship.recipient.preferred_email ])
    end

    it "confirms the agreement in the subject and shows the award and ticket link" do
      expect(mail.subject).to include("Your scholarship agreement is confirmed")
      body = mail.body.encoded
      expect(body).to include("$50")
      expect(body).to include(registration.slug)
    end
  end
end
