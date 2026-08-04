require "rails_helper"

RSpec.describe "Events::Callouts", type: :request do
  let(:registration) { create(:event_registration, event: event) }

  # These pages are reachable by slug (no login), so the built-in callout's
  # published state is the only gate. A hidden (or not-yet-materialized) callout
  # redirects back to the ticket so a stray link can't surface it.
  let(:event) { create(:event) }

  describe "GET /registration/:slug/faq" do
    it "renders the FAQ as collapsible toggles from the row's hydrated default content when published" do
      BuiltinCallouts.seed(event)
      event.registration_ticket_callouts.find_by(builtin_key: "faq").update!(hidden: false)
      get registration_faq_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("<details")
      expect(response.body).to include("Who is this training designed for?")
    end

    it "shows no content (no code fallback) once the FAQ description is blanked" do
      BuiltinCallouts.seed(event)
      event.registration_ticket_callouts.find_by(builtin_key: "faq").update!(description: "", hidden: false)
      get registration_faq_path(registration.slug)
      expect(response).to have_http_status(:success)
      # The default questions live on the row (hydrated), so blanking it shows
      # blank — the same as every other callout, not the code-defined default.
      expect(response.body).not_to include("Who is this training designed for?")
    end

    it "renders the editable FAQ callout copy when the card is materialized" do
      BuiltinCallouts.seed(event)
      faq = event.registration_ticket_callouts.find_by(builtin_key: "faq")
      faq.update!(description: "<details><summary>Custom question</summary><p>Custom answer</p></details>", hidden: false)

      get registration_faq_path(registration.slug)
      expect(response.body).to include("Custom question")
      expect(response.body).to include("Custom answer")
      expect(response.body).not_to include("Who is this training designed for?")
    end

    it "redirects to the ticket when the callout is hidden or absent" do
      get registration_faq_path(registration.slug)
      expect(response).to redirect_to(registration_ticket_path(registration.slug))
    end
  end

  # The intro copy an admin types into a built-in's materialized callout row (its
  # "Callout page text" / description) renders on that built-in's public page —
  # including its <details> dropdowns as styled toggles — the same way regardless
  # of which built-in it was entered into.
  describe "built-in page copy from the callout row description" do
    it "renders the CE callout's description on the CE page" do
      BuiltinCallouts.seed(event)
      event.registration_ticket_callouts.find_by(builtin_key: "ce_hours")
        .update!(description: "<p>Bring your license number.</p>", hidden: false)

      get registration_ce_path(registration.slug)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Bring your license number.")
    end

    it "renders the handouts callout's description (with dropdowns) on the handouts page" do
      create(:registration_ticket_callout, event:, builtin_key: "handouts", hidden: false,
             description: "<details><summary>What to bring</summary><p>Scissors and glue.</p></details>")

      get registration_handouts_path(registration.slug)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("What to bring")
      expect(response.body).to include("Scissors and glue.")
      # Rendered through _rich_content, so the disclosure becomes a styled toggle.
      expect(response.body).to include("<details")
    end

    it "renders the scholarship callout's description on the scholarship page" do
      registration.update!(scholarship_requested: true)
      BuiltinCallouts.seed(event)
      event.registration_ticket_callouts.find_by(builtin_key: "scholarship")
        .update!(description: "<p>About your scholarship.</p>", hidden: false)

      get registration_scholarship_path(registration.slug)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("About your scholarship.")
    end
  end

  describe "GET /registration/:slug/handouts" do
    it "renders the handouts page when its callout is published" do
      create(:registration_ticket_callout, event:, builtin_key: "handouts", hidden: false)
      get registration_handouts_path(registration.slug)
      expect(response).to have_http_status(:success)
    end

    it "shows each linked resource card with its join-row subtitle" do
      callout = create(:registration_ticket_callout, event:, builtin_key: "handouts", hidden: false)
      resource = create(:resource, title: "Aha Moments")
      create(:registration_ticket_callout_resource, registration_ticket_callout: callout,
             resource:, subtitle: "Reflect on the workshop", page_content: "Long detail copy.")

      get registration_handouts_path(registration.slug)

      expect(response.body).to include("Reflect on the workshop")
      # Page content is detail-page only, never on the card.
      expect(response.body).not_to include("Long detail copy.")
    end

    it "redirects to the ticket when the callout is hidden" do
      create(:registration_ticket_callout, event:, builtin_key: "handouts", hidden: true)
      get registration_handouts_path(registration.slug)
      expect(response).to redirect_to(registration_ticket_path(registration.slug))
    end
  end

  describe "callout page header" do
    let(:event) { create(:event, title: "Windows workshop", start_date: Date.new(2020, 1, 12), end_date: Date.new(2099, 12, 12)) }

    it "shows the event title and short date range under the callout title" do
      create(:registration_ticket_callout, event:, builtin_key: "staff", hidden: false)
      get registration_staff_path(registration.slug)
      # title · "<Mon D, 2020> - <Mon D, 2099>" — the short_date_range format
      # (no weekday, with year); the exact day depends on the request time zone.
      expect(response.body).to match(/Windows workshop · \w{3} \d{1,2}, 2020 - \w{3} \d{1,2}, 2099/)
    end
  end

  describe "GET /registration/:slug/staff" do
    it "renders the staff roster with the event's staff cards when published" do
      create(:registration_ticket_callout, event:, builtin_key: "staff", hidden: false,
             title: "Meet the staff")
      create(:event_staff, event:, person: create(:person, first_name: "Dana", last_name: "Facil"))

      get registration_staff_path(registration.slug)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Dana")
      expect(response.body).to include("Meet the staff")
    end

    it "renders the empty state when the event has no staff" do
      create(:registration_ticket_callout, event:, builtin_key: "staff", hidden: false)
      get registration_staff_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("None yet!")
    end

    it "titles the page with the callout row's editable title" do
      create(:registration_ticket_callout, event:, builtin_key: "staff", hidden: false,
             title: "Meet our facilitators")
      get registration_staff_path(registration.slug)
      expect(response.body).to include("Meet our facilitators")
    end

    it "renders the callout row's editable intro copy above the roster" do
      create(:registration_ticket_callout, event:, builtin_key: "staff", hidden: false,
             description: "<p>Say hi to our team.</p>")
      get registration_staff_path(registration.slug)
      expect(response.body).to include("Say hi to our team.")
    end

    it "redirects to the ticket when the callout is hidden or absent" do
      create(:registration_ticket_callout, event:, builtin_key: "staff", hidden: true)
      get registration_staff_path(registration.slug)
      expect(response).to redirect_to(registration_ticket_path(registration.slug))
    end

    it "shows a staff member's primary age range, gated by their profile toggle" do
      age_type = create(:category_type, name: "AgeRange", published: true)
      youth = create(:category, :published, category_type: age_type, name: "Youth")
      staffer = create(:person)
      staffer.tag_age_groups(primary_ids: [ youth.id ], additional_ids: [])
      create(:registration_ticket_callout, event:, builtin_key: "staff", hidden: false)
      create(:event_staff, event:, person: staffer)

      get registration_staff_path(registration.slug)
      expect(response.body).to include("Youth")

      staffer.update!(profile_show_age_ranges: false)
      get registration_staff_path(registration.slug)
      expect(response.body).not_to include("Youth")
    end

    it "shows an admin-only Edit staff button to admins" do
      create(:registration_ticket_callout, event:, builtin_key: "staff", hidden: false)
      sign_in create(:user, super_user: true)
      get registration_staff_path(registration.slug)
      expect(response.body).to include(edit_staff_event_path(event))
    end

    it "hides the Edit staff button from non-admin registrants" do
      create(:registration_ticket_callout, event:, builtin_key: "staff", hidden: false)
      get registration_staff_path(registration.slug)
      expect(response.body).not_to include(edit_staff_event_path(event))
    end
  end

  describe "GET /registration/:slug/payment" do
    let(:event) { create(:event, cost_cents: 10_000) }

    it "shows the W-9 document's materialized join-row subtitle, not hard-coded copy" do
      callout = create(:registration_ticket_callout, event:, builtin_key: "payment")
      w9 = create(:resource, title: "W-9")
      create(:registration_ticket_callout_resource, registration_ticket_callout: callout,
             resource: w9, subtitle: "Custom W-9 line")
      # The W-9 unlocks once an actual payment is on file.
      payment = create(:payment, type: "CashPayment", amount_cents: event.cost_cents, amount_cents_remaining: nil)
      create(:allocation, source: payment, allocatable: registration, amount: event.cost_cents)

      get registration_payment_path(registration.slug)

      expect(response.body).to include("Custom W-9 line")
      expect(response.body).not_to include("AWBW's W-9 tax form for your records")
    end
  end

  describe "GET /registration/:slug/videoconference" do
    let(:event) { create(:event, videoconference_url: "https://example.com/zoom") }

    it "links resources on the built-in callout to their own page, not inline" do
      resource = create(:resource)
      create(:downloadable_asset, owner: resource)
      create(:registration_ticket_callout, event:, builtin_key: "videoconference",
        title: "Videoconference", resources: [ resource ])

      get registration_videoconference_path(registration.slug)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(registration_resource_path(registration.slug, resource, return_to: "videoconference"))
      # The file itself is only shown on the resource's own page, not embedded here.
      expect(response.body).not_to include(rails_blob_path(resource.downloadable_asset.file, only_path: true))
    end

    it "lists both unlock conditions while the details aren't visible yet" do
      create(:registration_ticket_callout, event:, builtin_key: "videoconference",
        display_from: 23.days.from_now)

      get registration_videoconference_path(registration.slug)

      expect(response.body).to include("unlocks once both of these are met")
      expect(response.body).to include("Your payment is on file")
      expect(response.body).not_to include("https://example.com/zoom")

      # The checklist and the calendar hover surface the same unlock date (read
      # from the body to stay independent of the request's time zone).
      reveal_date = response.body[/Available from ([A-Z][a-z]+ \d{1,2}, \d{4})/, 1]
      expect(reveal_date).to be_present
      # "isn't" is HTML-escaped on the page (isn&#39;t), so match the apostrophe-free part.
      expect(response.body).to include("in this calendar entry yet")
      expect(response.body).to include("Re-download it from the Portal")
      expect(response.body).to include("on #{reveal_date}")
    end
  end

  # The single-resource page is where a document is actually shown: the inline
  # preview and download button live here, not on the callout list pages that
  # link to it.
  describe "GET /registration/:slug/resource/:resource_id" do
    let(:event) { create(:event) }

    context "with a PDF resource" do
      let(:resource) { create(:resource) }

      before { create(:downloadable_asset, owner: resource) }

      it "shows the PDF inline preview and a download button" do
        get registration_resource_path(registration.slug, resource)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("type=\"application/pdf\"")
        # Streamed same-origin via proxy mode so object-src :self covers it.
        expect(response.body).to include(rails_storage_proxy_path(resource.downloadable_asset.file, disposition: :inline))
        expect(response.body).to include("fa-download")
      end

      it "relaxes object-src to :self for the PDF <object> preview" do
        get registration_resource_path(registration.slug, resource)

        expect(response.headers["Content-Security-Policy-Report-Only"]).to include("object-src 'self'")
      end
    end

    context "with a non-PDF resource" do
      let(:resource) { create(:resource) }

      before { create(:downloadable_asset, :with_image, owner: resource) }

      it "renders the preview instead of an inline PDF viewer" do
        get registration_resource_path(registration.slug, resource)

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include("type=\"application/pdf\"")
      end
    end

    context "admin edit button" do
      let(:resource) { create(:resource) }

      it "shows an admin-only Edit link to change the PDF when signed in as an admin" do
        sign_in create(:user, super_user: true)

        get registration_resource_path(registration.slug, resource)

        expect(response.body).to include(edit_resource_path(resource))
      end

      it "hides the Edit link from registrants viewing the page" do
        get registration_resource_path(registration.slug, resource)

        expect(response.body).not_to include(edit_resource_path(resource))
      end
    end

    context "page content" do
      let(:resource) { create(:resource) }

      it "shows the join row's page content below the title" do
        callout = create(:registration_ticket_callout, event:, builtin_key: "handouts")
        create(:registration_ticket_callout_resource, registration_ticket_callout: callout,
               resource:, subtitle: "Short card line", page_content: "The longer page content copy.")

        get registration_resource_path(registration.slug, resource, return_to: "handouts")

        expect(response.body).to include("The longer page content copy.")
        # The subtitle is a card-only line, not shown on the resource page.
        expect(response.body).not_to include("Short card line")
      end

      it "shows no page content when the resource isn't linked to the origin callout" do
        create(:registration_ticket_callout, :builtin, event:, builtin_key: "handouts")

        get registration_resource_path(registration.slug, resource, return_to: "handouts")

        expect(response).to have_http_status(:success)
      end
    end

    context "eyebrow" do
      let(:resource) { create(:resource) }

      it "returns to the built-in callout it came from" do
        get registration_resource_path(registration.slug, resource, return_to: "videoconference")

        expect(response.body).to include(registration_videoconference_path(registration.slug))
      end

      it "returns to the custom callout it came from" do
        callout = create(:registration_ticket_callout, event:, title: "Parking")

        get registration_resource_path(registration.slug, resource, return_to: "callout", callout_id: callout.id)

        expect(response.body).to include(event_registration_ticket_callout_path(event, callout, reg: registration.slug))
        expect(response.body).to include("Back to Parking")
      end

      it "falls back to the ticket when reached directly" do
        get registration_resource_path(registration.slug, resource)

        expect(response.body).to include(registration_ticket_path(registration.slug))
        expect(response.body).to include("Back to ticket")
      end
    end
  end

  describe "GET /registration/:slug/ce" do
    context "when CE is registered" do
      let(:event) { create(:event) }

      before do
        license = create(:professional_license, person: registration.registrant, number: nil)
        create(:continuing_education_registration, event_registration: registration, professional_license: license)
      end

      it "renders the CE page" do
        get registration_ce_path(registration.slug)
        expect(response).to have_http_status(:success)
      end

      context "with checkout=success" do
        it "shows a success flash" do
          get registration_ce_path(registration.slug, checkout: "success")
          expect(flash[:notice]).to eq("Your CE payment was successful.")
        end
      end

      context "with checkout=cancelled" do
        it "shows a cancelled flash" do
          get registration_ce_path(registration.slug, checkout: "cancelled")
          expect(flash[:alert]).to eq("CE payment was cancelled. You can try again whenever you're ready.")
        end
      end
    end

    context "when CE is not registered" do
      let(:event) { create(:event, ce_hours_offered: 6) }

      it "renders the opt-in form inside the flip frame" do
        get registration_ce_path(registration.slug)
        expect(response).to have_http_status(:success)
        button = Nokogiri::HTML(response.body).at_css("turbo-frame#ce_request_section input[value='Request CE credit']")
        expect(button).to be_present
      end

      it "flips the frame to the license section once CE is requested" do
        post registration_ce_request_path(registration.slug)

        # Turbo re-fetches the redirect target for the frame; the same frame now
        # carries the license-entry section instead of the opt-in button.
        get registration_ce_path(registration.slug), headers: { "Turbo-Frame" => "ce_request_section" }
        frame = Nokogiri::HTML(response.body).at_css("turbo-frame#ce_request_section")
        expect(frame.text).to include("Your CE credit")
        expect(frame.text).not_to include("Request CE credit")
      end
    end

    context "when the event has a CE fee" do
      let(:event) do
        create(:event, ce_hours_offered: 6, ce_hours_cost_cents: 15_000,
               ce_payment_due_deadline: Time.zone.local(2026, 7, 22, 9, 0))
      end

      it "states the concrete fee on the opt-in page before registering" do
        get registration_ce_path(registration.slug)
        expect(response.body).to include("CE hours are available for $150.")
      end

      it "links a locked license's 'Contact us' out of the Turbo frame to the contact page" do
        license = create(:professional_license, person: registration.registrant, number: "LIC-7")
        create(:continuing_education_registration, event_registration: registration,
               professional_license: license, certificate_sent_at: Time.current)

        get registration_ce_path(registration.slug)
        link = Nokogiri::HTML(response.body).at_css("turbo-frame#license_section a[href='#{contact_us_path}']")
        expect(link).to be_present
        expect(link["data-turbo-frame"]).to eq("_top")
      end

      context "once CE is registered with a balance due" do
        before do
          license = create(:professional_license, person: registration.registrant, number: "LIC-9")
          create(:continuing_education_registration, event_registration: registration,
                 professional_license: license, cost_cents: 15_000)
        end

        it "surfaces the payment-due deadline as a stat" do
          get registration_ce_path(registration.slug)
          expect(response.body).to include("Payment due")
          expect(response.body).to include("on July 22, 2026")
        end

        it "omits the payment-due deadline once paid in full" do
          ce = registration.continuing_education_registrations.first
          payment = create(:payment, person: registration.registrant, amount_cents: 15_000, amount_cents_remaining: nil)
          create(:allocation, source: payment, allocatable: ce, amount: 15_000)

          get registration_ce_path(registration.slug)
          expect(response.body).not_to include("on July 22, 2026")
        end
      end
    end
  end

  describe "POST /registration/:slug/ce/pay" do
    let(:event) { create(:event, ce_hours_offered: 6, ce_hours_cost_cents: 15_000) }
    let(:fake_session) { double(url: "https://checkout.stripe.com/test", id: "cs_test_123") }

    before do
      license = create(:professional_license, person: registration.registrant, number: "LIC-1")
      create(:continuing_education_registration, event_registration: registration,
             professional_license: license, cost_cents: 15_000)

      fake_processor = double(checkout: fake_session)
      allow_any_instance_of(Person).to receive(:set_payment_processor)
      allow_any_instance_of(Person).to receive(:payment_processor).and_return(fake_processor)
    end

    it "redirects to Stripe Checkout when a CE balance is due" do
      post registration_ce_pay_path(registration.slug)
      expect(response).to redirect_to("https://checkout.stripe.com/test")
      expect(response.status).to eq(303)
    end

    it "includes ce_registration_id and event_registration_id in the checkout metadata" do
      captured = nil
      fake_processor = double
      allow(fake_processor).to receive(:checkout) { |params| captured = params; fake_session }
      allow_any_instance_of(Person).to receive(:set_payment_processor)
      allow_any_instance_of(Person).to receive(:payment_processor).and_return(fake_processor)

      post registration_ce_pay_path(registration.slug)

      expect(captured[:metadata]).to include(
        ce_registration_id: registration.continuing_education_registrations.first.id,
        event_registration_id: registration.id
      )
    end

    it "updates the checkout_session_id on the registration" do
      post registration_ce_pay_path(registration.slug)
      expect(registration.reload.checkout_session_id).to eq("cs_test_123")
    end

    context "when no CE registration exists" do
      before { registration.continuing_education_registrations.destroy_all }

      it "redirects with an alert" do
        post registration_ce_pay_path(registration.slug)
        expect(response).to redirect_to(registration_ce_path(registration.slug))
        expect(flash[:alert]).to eq("No CE payment is due.")
      end
    end

    context "when the CE balance is zero" do
      before do
        registration.continuing_education_registrations.first.update!(cost_cents: 0)
      end

      it "redirects with an alert" do
        post registration_ce_pay_path(registration.slug)
        expect(response).to redirect_to(registration_ce_path(registration.slug))
        expect(flash[:alert]).to eq("No CE payment is due.")
      end
    end
  end

  # Shared setup for the scholarship callout page and its agree action.
  context "scholarship agreement" do
    let(:event)        { create(:event, cost_cents: 10_000) }
    let(:registration) { create(:event_registration, event: event, scholarship_requested: true) }
    let(:scholarship)  { create(:scholarship, recipient: registration.registrant, amount_cents: 5_000) }
    let!(:allocation)  { create(:allocation, source: scholarship, allocatable: registration, amount: 5_000) }

    describe "GET /registration/:slug/scholarship" do
      it "shows the amount as offered with an Agree button while unsigned" do
        get registration_scholarship_path(registration.slug)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Amount offered")
        expect(response.body).to include("Pending agreement")
        expect(response.body).to match(/name="agreement" value="yes"/)
      end

      it "shows the award as signed with the date once the agreement is signed" do
        scholarship.update!(agreement_signed: true)
        get registration_scholarship_path(registration.slug)

        expect(response.body).to include("Amount awarded")
        expect(response.body).to include("Agreement signed")
        expect(response.body).not_to include("Pending agreement")
      end
    end

    describe "POST /registration/:slug/scholarship/agreement" do
      it "signs the agreement and stamps the time when Agree is submitted" do
        expect(scholarship.agreement_signed?).to be(false)

        post registration_scholarship_agreement_path(registration.slug), params: { agreement: "yes" }

        expect(response).to redirect_to(registration_scholarship_path(registration.slug))
        expect(scholarship.reload.agreement_signed?).to be(true)
        expect(scholarship.agreement_signed_at).to be_present
      end

      it "does not sign the agreement without an affirmative submission" do
        post registration_scholarship_agreement_path(registration.slug), params: { agreement: "" }

        expect(response).to redirect_to(registration_scholarship_path(registration.slug))
        expect(scholarship.reload.agreement_signed?).to be(false)
      end

      it "redirects to the scholarship page when there is no awarded scholarship" do
        other = create(:event_registration, event: event, scholarship_requested: true)

        post registration_scholarship_agreement_path(other.slug), params: { agreement: "yes" }

        expect(response).to redirect_to(registration_scholarship_path(other.slug))
      end
    end
  end

  describe "GET /registration/:slug/certificate" do
    let(:event) { create(:event, end_date: 2.days.ago) }
    let(:registration) { create(:event_registration, event: event, status: "attended") }

    it "renders the certificate once it is unlocked" do
      get registration_certificate_path(registration.slug)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("This certifies that")
    end

    it "shows the pending unlock conditions when the certificate isn't unlocked yet" do
      registration.update!(status: "registered")

      get registration_certificate_path(registration.slug)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("unlocks once these are met")
      expect(response.body).to include("Your attendance is confirmed")
      expect(response.body).not_to include("This certifies that")
    end

    it "adds the CE accreditation clause once CE credit is registered and paid" do
      event.update!(ce_hours_offered: 6)
      license = create(:professional_license, person: registration.registrant, number: "LIC-1")
      registration.continuing_education_registrations.create!(professional_license: license, hours: 6, cost_cents: 0)

      get registration_certificate_path(registration.slug)

      expect(response.body).to include("continuing education (CE) credit")
      expect(response.body).to include(ContinuingEducationRegistration::ACCREDITATION_URL)
      expect(response.body).to include("provider ##{ContinuingEducationRegistration::ACCREDITATION_PROVIDER_NUMBER}")
    end

    it "unlocks the certificate when the CE credit was issued even without tracked attendance" do
      registration.update!(status: "registered")
      event.update!(ce_hours_offered: 6, end_date: 2.days.from_now)
      license = create(:professional_license, person: registration.registrant, number: "LIC-3")
      ce = registration.continuing_education_registrations.create!(professional_license: license, hours: 6)
      ce.mark_certificate_sent!

      get registration_certificate_path(registration.slug)

      expect(response.body).to include("This certifies that")
      expect(response.body).to include("continuing education (CE) credit")
    end

    it "adds the CE clause when the credit was issued even if a balance remains" do
      event.update!(ce_hours_offered: 6, ce_hours_cost_cents: 12_000)
      license = create(:professional_license, person: registration.registrant, number: "LIC-2")
      ce = registration.continuing_education_registrations.create!(professional_license: license, hours: 6)
      ce.mark_certificate_sent!

      get registration_certificate_path(registration.slug)

      expect(response.body).to include("continuing education (CE) credit")
    end

    it "surfaces CE status above the certificate (screen-only) when CE isn't earned yet" do
      event.update!(ce_hours_offered: 6, ce_hours_cost_cents: 12_000)
      license = create(:professional_license, person: registration.registrant, number: "LIC-4")
      registration.continuing_education_registrations.create!(professional_license: license, hours: 6)

      get registration_certificate_path(registration.slug)

      expect(response.body).to include("This certifies that")
      expect(response.body).to include("isn't shown on this certificate yet")
      # The gated note never joins the printed CE clause.
      expect(response.body).not_to include("in accordance with our approval by")
    end

    it "omits the CE clause when no CE credit was earned" do
      get registration_certificate_path(registration.slug)

      expect(response.body).not_to include(ContinuingEducationRegistration::ACCREDITATION_URL)
    end
  end

  describe "POST /registration/:slug/ce/license" do
    let(:event) { create(:event) }

    context "with a CE registration on file" do
      before do
        license = create(:professional_license, person: registration.registrant, number: nil)
        create(:continuing_education_registration, event_registration: registration, professional_license: license)
      end

      it "saves the license and mirrors it onto the CE form answer" do
        post registration_ce_license_path(registration.slug),
          params: { license_number: "LIC-999", license_kind: "LCSW", license_issuing_state: "TN" }

        expect(response).to redirect_to(registration_ce_path(registration.slug))
        expect(flash[:notice]).to eq("License saved.")
        expect(registration.reload.continuing_education_registrations.first.professional_license.number).to eq("LIC-999")
      end

      it "refuses to change the license once the certificate has been issued" do
        registration.continuing_education_registrations.first.update!(certificate_sent_at: Time.current)

        post registration_ce_license_path(registration.slug), params: { license_number: "LIC-999" }

        expect(response).to redirect_to(registration_ce_path(registration.slug))
        expect(flash[:alert]).to include("can no longer be changed here")
      end
    end

    context "when no CE registration exists" do
      it "redirects to the CE page" do
        post registration_ce_license_path(registration.slug), params: { license_number: "LIC-999" }

        expect(response).to redirect_to(registration_ce_path(registration.slug))
      end
    end
  end

  describe "POST /registration/:slug/ce/request" do
    context "when the event offers CE hours" do
      let(:event) { create(:event, ce_hours_offered: 6, ce_hours_cost_cents: 15_000) }

      it "creates a CE registration against a placeholder license and redirects" do
        expect(registration.continuing_education_registrations).to be_empty

        post registration_ce_request_path(registration.slug)

        expect(response).to redirect_to(registration_ce_path(registration.slug))
        expect(flash[:notice]).to eq("Continuing education credit requested.")
        expect(registration.reload.continuing_education_registrations.count).to eq(1)
      end

      it "doesn't create a second CE registration if one already exists" do
        license = create(:professional_license, person: registration.registrant)
        create(:continuing_education_registration, event_registration: registration, professional_license: license)

        expect { post registration_ce_request_path(registration.slug) }
          .not_to change { registration.reload.continuing_education_registrations.count }
      end
    end

    context "when the event offers no CE hours" do
      let(:event) { create(:event) }

      it "redirects without creating a CE registration" do
        post registration_ce_request_path(registration.slug)

        expect(response).to redirect_to(registration_ce_path(registration.slug))
        expect(registration.reload.continuing_education_registrations).to be_empty
      end
    end
  end
end
