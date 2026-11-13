require "rails_helper"

RSpec.describe "Payments", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }

  before { sign_in admin }

  describe "GET /payments index frame" do
    it "renders the lazy results frame without erroring" do
      create(:payment, person: person, amount_cents: 5000, amount_cents_remaining: 5000)

      get payments_path, headers: { "Turbo-Frame" => "payments_results" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("payments_results")
      expect(response.body).to include(person.name)
    end

    it "totals every payment matching the filters, not just the page" do
      CashPayment.create!(person:, amount_cents: 10_000, amount_cents_remaining: 0)
      CheckPayment.create!(person:, amount_cents: 2_500, check_number: "1")
      CashPayment.create!(person: create(:person), amount_cents: 99_900)

      get payments_path(person_id: person.id, number_of_items_per_page: 1), headers: { "Turbo-Frame" => "payments_results" }

      text = Nokogiri::HTML(response.body).text.squish
      expect(text).to include("2 payments", "Total $125", "Unallocated $25")
    end

    it "breaks the row's amount link out of the results frame" do
      payment = create(:payment, person: person, amount_cents: 5000, amount_cents_remaining: 5000)

      get payments_path, headers: { "Turbo-Frame" => "payments_results" }

      expect_frame_breakout(response.body, payment_path(payment))
    end
  end

  describe "GET /payments/:id eyebrow" do
    let(:event) { create(:event, cost_cents: 5000) }
    let(:submission) { create(:form_submission, event: event, role: "bulk_payment") }
    let(:payment) { create(:payment, form_submission: submission, amount_cents: 5000, amount_cents_remaining: 5000) }

    it "returns to the expanded bulk-payment card when arrived from bulk payments" do
      get payment_path(payment, return_to: "bulk_payments", expand: submission.id)

      expect(response.body).to include("← Bulk payments")
      expect(response.body).to include(bulk_payments_event_path(event, expand: submission.id, anchor: "payment-card-#{submission.id}"))
    end

    it "carries the return context onto the Allocate link" do
      get payment_path(payment, return_to: "bulk_payments", expand: submission.id)

      expect(response.body).to match(%r{/allocations/new\?expand=#{submission.id}&amp;return_to=bulk_payments})
    end

    it "falls back to the payments index otherwise" do
      get payment_path(payment)

      expect(response.body).to include("← Payments")
    end
  end

  describe "GET /payments/:id linked records" do
    it "links the payer but not the form submission or its event" do
      event = create(:event, cost_cents: 5000)
      submission = create(:form_submission, event:, role: "bulk_payment")
      payment = create(:payment, person:, form_submission: submission)

      get payment_path(payment)

      expect(response.body).to include(%(href="#{person_path(person)}"))
      expect(response.body).not_to include(%(href="#{event_path(event)}"))
      expect(response.body).not_to include(%(href="#{form_submission_path(submission)}"))
    end
  end

  describe "POST /payments" do
    context "when allocating a manual payment to a membership invoice with an open checkout" do
      let(:invoice) { create(:membership_invoice, cost_cents: 5_000) }

      before do
        invoice.update_columns(payment_in_progress_at: Time.current, checkout_session_id: "cs_test_123")
      end

      it "does not create a payment or allocation and explains why" do
        expect {
          post payments_path, params: {
            payment: {
              type: "CashPayment",
              payer_type: "Person",
              person_id: person.id,
              amount_dollars: "10.00",
              allocatable_sgid: invoice.to_sgid.to_s
            }
          }
        }.to change(Payment, :count).by(0)
          .and change(Allocation, :count).by(0)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("A payment is already in progress for this invoice.")
      end
    end

    context "when recording a check payment with a memo" do
      let(:event) { create(:event, cost_cents: 10_000) }
      let(:registration) { create(:event_registration, event:) }

      it "stores the check number and memo" do
        post payments_path, params: {
          payment: {
            type: "CheckPayment",
            payer_type: "Person",
            person_id: person.id,
            amount_dollars: "50.00",
            check_number: "1234",
            memo: "Spring workshop",
            allocatable_sgid: registration.to_sgid.to_s
          }
        }

        payment = Payment.last
        expect(payment.check_number).to eq("1234")
        expect(payment.memo).to eq("Spring workshop")
      end
    end
  end

  describe "POST /payments for a ContinuingEducationRegistration" do
    let(:ce) { create(:continuing_education_registration, cost_cents: 5_000) }

    before { sign_in admin }

    it "records the payment against the CE registration's registrant" do
      expect {
        post payments_path, params: {
          payment: {
            type: "CashPayment",
            payer_type: "Person",
            amount_dollars: "50.00",
            allocatable_sgid: ce.to_sgid.to_s
          }
        }
      }.to change(Payment, :count).by(1)
        .and change(Allocation, :count).by(1)

      expect(Payment.last.person).to eq(ce.event_registration.registrant)
      expect(ce.reload).to be_paid_in_full
    end
  end

  describe "POST /payments/allocation_form" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:registration) { create(:event_registration, event:) }

    it "renders compound payer and additional designation pickers" do
      post allocation_form_payments_path,
        params: { type: "CashPayment", allocatable_sgid: registration.to_sgid.to_s },
        as: :turbo_stream

      expect(response.body).to include("Whose account is the money coming from?")
      expect(response.body).to include("payment[payer_sgid]")
      expect(response.body).to include("payment[additional_designation_sgid]")
      expect(response.body).to include("Additional designation")
    end

    it "preselects the registrant in a compound picker" do
      post allocation_form_payments_path,
        params: { type: "CashPayment", allocatable_sgid: registration.to_sgid.to_s },
        as: :turbo_stream

      expect(response.body).to match(%r{<option[^>]*selected[^>]*>#{Regexp.escape(registration.registrant.full_name)}[^<]*Person</option>})
    end
  end

  describe "GET /payments/:id/edit FileMaker code" do
    it "renders the FileMaker code field" do
      payment = create(:payment, person:)

      get edit_payment_path(payment)

      expect(response.body).to include("payment[filemaker_code]")
    end

    it "links each archived code to the FileMaker payments archive" do
      FmPayment.create!(fm_id: "D29186", data: {})
      payment = create(:payment, person:, filemaker_code: "D29186, D99999")

      get edit_payment_path(payment)

      expect(response.body).to include(fm_archive_path("D29186", table: "payments"))
      expect(response.body).to include("No FileMaker archive record for D99999")
      expect(response.body).not_to include(fm_archive_path("D99999", table: "payments"))
    end
  end

  describe "PATCH /payments/:id" do
    let(:organization) { create(:organization) }

    it "updates the check number and memo on a check payment" do
      payment = CheckPayment.create!(person:, amount_cents: 5_000, check_number: "1234", memo: "Old memo")

      get edit_payment_path(payment)
      expect(response.body).to include("payment[check_number]")
      expect(response.body).to include("payment[memo]")

      patch payment_path(payment), params: {
        payment: { payer_sgid: person.to_sgid.to_s, check_number: "5678", memo: "Spring workshop" }
      }

      payment.reload
      expect(payment.check_number).to eq("5678")
      expect(payment.memo).to eq("Spring workshop")
    end

    it "records an Ahoy update event with the before and after values" do
      payment = CheckPayment.create!(person:, amount_cents: 5_000, check_number: "1234", memo: "Old memo")
      # The request spec client reads as a bot, which Ahoy skips by default.
      allow(Ahoy).to receive(:track_bots).and_return(true)

      expect {
        patch payment_path(payment), params: {
          payment: { payer_sgid: person.to_sgid.to_s, check_number: "5678", memo: "Spring workshop" }
        }
      }.to change { Ahoy::Event.where(name: "update.payment", resource_id: payment.id).count }.by(1)

      changes = Ahoy::Event.where(name: "update.payment", resource_id: payment.id).last.properties["changes"]
      expect(changes["memo"]).to eq("before" => "Old memo", "after" => "Spring workshop")
      expect(changes["check_number"]).to eq("before" => "1234", "after" => "5678")
    end

    it "updates the FileMaker code" do
      payment = create(:payment, person:)

      patch payment_path(payment), params: {
        payment: { payer_sgid: person.to_sgid.to_s, filemaker_code: "D29186" }
      }

      expect(payment.reload.filemaker_code).to eq("D29186")
    end

    it "updates payer and designation via sgids" do
      payment = create(:payment, person:, organization: nil)

      patch payment_path(payment), params: {
        payment: {
          payer_sgid: organization.to_sgid.to_s,
          additional_designation_sgid: person.to_sgid.to_s
        }
      }

      payment.reload
      expect(payment.payer_type).to eq("Organization")
      expect(payment.organization).to eq(organization)
      expect(payment.person).to eq(person)
    end

    it "clears the additional designation when blank is sent" do
      payment = create(:payment, person:, organization:, payer_type: "Organization")

      patch payment_path(payment), params: {
        payment: {
          payer_sgid: organization.to_sgid.to_s,
          additional_designation_sgid: ""
        }
      }

      payment.reload
      expect(payment.organization).to eq(organization)
      expect(payment.person).to be_nil
    end
  end

  describe "comments and communications on a payment" do
    it "keeps comments off the new and edit forms" do
      payment = create(:payment, person:)

      get new_payment_path(type: "CheckPayment")
      expect(response.body).not_to include("comments_attributes")

      get edit_payment_path(payment)
      expect(response.body).not_to include("comments_attributes")
    end

    it "lists the payment's comments and communications on the show page" do
      payment = create(:payment, person:)
      create(:comment, commentable: payment, topic: "Follow-up", body: "Called about the remaining balance")
      create(:notification, noticeable: payment, email_subject: "Left a voicemail")

      get payment_path(payment)

      expect(response.body).to include("Comments &amp; communications", "Called about the remaining balance", "Left a voicemail")
    end

    it "adds a comment from the show page and lands back on it" do
      payment = CheckPayment.create!(person:, amount_cents: 5_000, check_number: "1234")

      expect {
        post payment_comments_path(payment), params: { comment: { topic: "Follow-up", body: "Called about the check" } },
                                             headers: { "HTTP_REFERER" => "http://www.example.com#{payment_path(payment)}" }
      }.to change { payment.comments.count }.by(1)

      expect(response).to redirect_to(payment_path(payment))
      comment = payment.comments.last
      expect(comment.body).to eq("Called about the check")
      expect(comment.created_by).to eq(admin)
    end
  end

  describe "payer/additional designation via sgids" do
    let(:event) { create(:event, cost_cents: 10_000) }
    let(:registration) { create(:event_registration, event:) }
    let(:organization) { create(:organization) }

    it "creates a payment from an organization payer and a person designation" do
      post payments_path, params: {
        payment: {
          type: "CheckPayment",
          check_number: "1234",
          payer_sgid: organization.to_sgid.to_s,
          additional_designation_sgid: registration.registrant.to_sgid.to_s,
          amount_dollars: "50.00",
          allocatable_sgid: registration.to_sgid.to_s
        }
      }

      payment = Payment.last
      expect(payment.payer_type).to eq("Organization")
      expect(payment.organization).to eq(organization)
      expect(payment.person).to eq(registration.registrant)
    end

    it "rejects two people without creating a payment" do
      other_person = create(:person)

      expect {
        post payments_path, params: {
          payment: {
            type: "CashPayment",
            payer_sgid: registration.registrant.to_sgid.to_s,
            additional_designation_sgid: other_person.to_sgid.to_s,
            amount_dollars: "50.00",
            allocatable_sgid: registration.to_sgid.to_s
          }
        }
      }.to change(Payment, :count).by(0)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("must be different kinds")
    end

    it "creates a payment from a person payer with no additional designation" do
      post payments_path, params: {
        payment: {
          type: "CashPayment",
          payer_sgid: registration.registrant.to_sgid.to_s,
          additional_designation_sgid: "",
          amount_dollars: "50.00",
          allocatable_sgid: registration.to_sgid.to_s
        }
      }

      payment = Payment.last
      expect(payment.payer_type).to eq("Person")
      expect(payment.person).to eq(registration.registrant)
      expect(payment.organization).to be_nil
    end

    it "creates a standalone payment from sgids without an allocatable" do
      organization = create(:organization)

      post payments_path, params: {
        payment: {
          type: "CashPayment",
          payer_sgid: organization.to_sgid.to_s,
          additional_designation_sgid: registration.registrant.to_sgid.to_s,
          amount_dollars: "25.00"
        }
      }

      payment = Payment.last
      expect(payment.payer_type).to eq("Organization")
      expect(payment.organization).to eq(organization)
      expect(payment.person).to eq(registration.registrant)
      expect(payment.allocations).to be_empty
    end
  end
end
