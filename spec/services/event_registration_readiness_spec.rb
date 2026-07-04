require "rails_helper"

RSpec.describe EventRegistrationReadiness do
  let(:event) { create(:event, cost_cents: 1000) }
  let(:registration) { create(:event_registration, event: event, status: "registered") }
  let(:submitted_org_name) { nil }
  subject(:readiness) { described_class.new(registration, submitted_org_name: submitted_org_name) }

  def pay(reg, cents)
    create(:allocation,
      source: create(:payment, amount_cents: cents, amount_cents_remaining: cents),
      allocatable: reg, amount: cents)
  end

  def award_scholarship(reg, tasks_completed:, amount: 1000)
    scholarship = create(:scholarship, recipient: reg.registrant, tasks_completed: tasks_completed, amount_cents: amount)
    create(:allocation, source: scholarship, allocatable: reg, amount: amount)
    scholarship
  end

  describe "#event_ready?" do
    it "is ready when paid in full with no organization, scholarship, or CE concerns" do
      pay(registration, 1000)

      expect(readiness.event_ready?).to be(true)
      expect(readiness.event_ready_issues).to be_empty
    end

    it "flags payment due when the event has a cost and is not paid in full" do
      expect(readiness.event_ready_issues).to include("Payment due")
      expect(readiness.event_ready?).to be(false)
    end

    it "does not flag payment for a free event" do
      event.update!(cost_cents: 0)

      expect(readiness.event_ready_issues).not_to include("Payment due")
    end

    it "ignores the intends-to-pay flag (access only, not readiness)" do
      registration.update!(intends_to_pay: true)

      expect(readiness.event_ready_issues).to include("Payment due")
    end

    context "organization" do
      let(:organization) { create(:organization, name: "Helping Hands") }

      it "flags an org answer that is not linked to a registration" do
        pay(registration, 1000)
        readiness = described_class.new(registration, submitted_org_name: "Some Unlisted Org")

        expect(readiness.event_ready_issues).to include("Organization not linked")
      end

      it "does not flag when the submitted org matches a linked org (and a facilitator affiliation exists)" do
        pay(registration, 1000)
        create(:event_registration_organization, event_registration: registration, organization: organization)
        create(:affiliation, person: registration.registrant, organization: organization, title: "Facilitator")
        readiness = described_class.new(registration, submitted_org_name: "Helping Hands")

        expect(readiness.event_ready_issues).not_to include("Organization not linked")
        expect(readiness.event_ready_issues).not_to include("Not a facilitator at a linked organization")
      end

      it "does not flag an unlinked org answer once any organization is linked" do
        pay(registration, 1000)
        create(:event_registration_organization, event_registration: registration, organization: organization)
        create(:affiliation, person: registration.registrant, organization: organization, title: "Facilitator")
        readiness = described_class.new(registration, submitted_org_name: "A Different Unlisted Agency")

        expect(readiness.event_ready_issues).not_to include("Organization not linked")
      end

      it "flags a linked org the registrant has no facilitator affiliation for" do
        pay(registration, 1000)
        create(:event_registration_organization, event_registration: registration, organization: organization)

        expect(readiness.event_ready_issues).to include("Not a facilitator at a linked organization")
      end

      it "does not count a non-facilitator affiliation as satisfying the requirement" do
        pay(registration, 1000)
        create(:event_registration_organization, event_registration: registration, organization: organization)
        create(:affiliation, person: registration.registrant, organization: organization, title: "Volunteer")

        expect(readiness.event_ready_issues).to include("Not a facilitator at a linked organization")
      end
    end

    context "scholarship" do
      it "flags a requested scholarship that has not been created" do
        pay(registration, 1000)
        registration.update!(scholarship_requested: true)

        expect(readiness.event_ready_issues).to include("Scholarship not created")
      end

      it "flags an awarded scholarship whose tasks are incomplete" do
        award_scholarship(registration, tasks_completed: false, amount: 1000)

        expect(readiness.event_ready_issues).to include("Scholarship tasks incomplete")
      end

      it "does not flag an awarded scholarship whose tasks are complete" do
        award_scholarship(registration, tasks_completed: true, amount: 1000)

        expect(readiness.event_ready_issues).not_to include("Scholarship tasks incomplete")
        expect(readiness.event_ready_issues).not_to include("Scholarship not created")
      end
    end

    context "continuing education" do
      it "flags CE as unpaid when CE credit is requested (no CE payment is tracked yet)" do
        pay(registration, 1000)
        registration.update!(ce_credit_requested: true, ce_license_number: "LIC123")

        expect(readiness.event_ready_issues).to include("CE not paid")
      end

      it "flags a missing CE license number when CE credit is requested" do
        pay(registration, 1000)
        registration.update!(ce_credit_requested: true, ce_license_number: nil)

        expect(readiness.event_ready_issues).to include("CE license number missing")
      end

      it "does not flag CE concerns when CE credit was not requested" do
        pay(registration, 1000)

        expect(readiness.event_ready_issues).not_to include("CE not paid")
        expect(readiness.event_ready_issues).not_to include("CE license number missing")
      end
    end
  end

  describe "#completed? / #completion_issues" do
    it "flags non-attendance when the registrant has not attended" do
      registration.update!(status: "registered")

      expect(readiness.completion_issues).to include("Did not attend")
      expect(readiness.completed?).to be(false)
    end

    it "treats incomplete attendance as not satisfying the post-event criteria" do
      registration.update!(status: "incomplete_attendance")

      expect(readiness.completion_issues).to include("Attendance incomplete")
    end

    it "does not flag attendance once the registrant has attended" do
      registration.update!(status: "attended")

      expect(readiness.completion_issues).not_to include("Did not attend")
      expect(readiness.completion_issues).not_to include("Attendance incomplete")
    end

    it "flags an awarded scholarship whose tasks are incomplete" do
      registration.update!(status: "attended")
      award_scholarship(registration, tasks_completed: false, amount: 1000)

      expect(readiness.completion_issues).to include("Scholarship tasks incomplete")
    end

    it "flags the registration certificate as unsent until certificate_sent_at is set" do
      registration.update!(status: "attended")

      expect(readiness.completion_issues).to include("Certificate not sent")
    end

    it "clears the registration certificate issue once it has been sent" do
      registration.update!(status: "attended", certificate_sent_at: Time.current)

      expect(readiness.completion_issues).not_to include("Certificate not sent")
    end

    it "flags the CE certificate as unsent when CE credit was requested" do
      registration.update!(status: "attended", ce_credit_requested: true)

      expect(readiness.completion_issues).to include("CE certificate not sent")
    end

    it "does not flag a CE certificate when CE credit was not requested" do
      registration.update!(status: "attended")

      expect(readiness.completion_issues).not_to include("CE certificate not sent")
    end
  end

  describe "#status" do
    it "is :not_ready when a pre-event condition is outstanding" do
      # default registrant is unpaid on a paid event
      expect(readiness.status).to eq(:not_ready)
      expect(readiness.status_label).to eq("Not ready")
    end

    it "is :ready once the pre-event checklist is clear but no post-event work is done" do
      pay(registration, 1000)
      registration.update!(status: "registered")

      expect(readiness.status).to eq(:ready)
      expect(readiness.status_label).to eq("Ready")
    end

    it "is :certificate_due once the post-event work is done but the certificate is unsent" do
      pay(registration, 1000)
      registration.update!(status: "attended")

      expect(readiness.status).to eq(:certificate_due)
      expect(readiness.status_label).to eq("Certificate pending")
    end

    it "is :completed once attended and the certificate has been sent" do
      pay(registration, 1000)
      registration.update!(status: "attended", certificate_sent_at: Time.current)

      expect(readiness.status).to eq(:completed)
      expect(readiness.status_label).to eq("Completed")
    end

    it "prefers :completed over the pre-event checklist when completion is reached" do
      allow(readiness).to receive(:completed?).and_return(true)

      expect(readiness.status).to eq(:completed)
      expect(readiness.status_label).to eq("Completed")
    end
  end

  describe "#event_ready_reason" do
    it "is nil when the pre-event checklist is clear" do
      pay(registration, 1000)

      expect(readiness.event_ready_reason).to be_nil
    end

    it "gives a two-word reason for the highest-priority outstanding item" do
      # unpaid (highest priority) trumps a later org issue
      organization = create(:organization, name: "Helping Hands")
      create(:event_registration_organization, event_registration: registration, organization: organization)

      expect(readiness.event_ready_reason).to eq("Payment due")
    end

    it "summarizes an organization problem as 'Org validation'" do
      pay(registration, 1000)
      organization = create(:organization, name: "Helping Hands")
      create(:event_registration_organization, event_registration: registration, organization: organization)

      expect(readiness.event_ready_reason).to eq("Org validation")
    end
  end

  describe "#status_reason" do
    it "names the outstanding pre-event reason when not ready" do
      expect(readiness.status_reason).to eq("Payment due")
    end

    it "names the outstanding certificate when certificate-pending" do
      pay(registration, 1000)
      registration.update!(status: "attended")

      expect(readiness.status_reason).to eq("Registration")
    end

    it "is nil when ready" do
      pay(registration, 1000)
      registration.update!(status: "registered")

      expect(readiness.status_reason).to be_nil
    end
  end

  describe "#certificate_due_reason" do
    it "names the registration certificate when no CE was requested" do
      expect(readiness.certificate_due_reason).to eq("Registration")
    end

    it "names both certificates when CE credit was requested" do
      registration.update!(ce_credit_requested: true)

      expect(readiness.certificate_due_reason).to eq("Reg + CE")
    end
  end
end
