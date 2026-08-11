module Events
  # Public show pages for a registration ticket's built-in callouts (payment, CE,
  # scholarship, handouts, videoconference, FAQ, certificate, LinkedIn badge).
  # Each is reachable by the registration slug — the slug is the authorization,
  # so no login is required (mirrors the public ticket/invoice pages).
  class CalloutsController < ApplicationController
    # Real registrant pages are public (the slug is the authorization); the
    # sample-ticket previews instead require an admin (authorized in #authorize_callout).
    skip_before_action :authenticate_user!, unless: :sample_preview?
    before_action :set_event_registration
    before_action :authorize_callout
    before_action :set_event
    # These pages carry an editable intro (the built-in row's "Callout page text")
    # above the app-controlled content, plus any resources linked to the row.
    before_action :set_builtin_content, only: %i[ payment scholarship certificate linkedin_badge videoconference staff ]

    helper_method :sample_preview?

    # The single-resource page previews a PDF in an <object> (object-src). The
    # global policy blocks <object>/<embed> with object_src :none; relax to :self
    # only here, matching ResourcesController#show. The blob streams same-origin
    # via proxy mode, so :self covers it.
    content_security_policy(only: :resource) do |policy|
      policy.object_src :self
    end

    # Payment page: the full allocation ledger with the running balance due, plus
    # the linked documents (the W-9 from the payment callout's resources, and the
    # dynamic invoice/receipt) for paid events.
    def payment
      # The sample preview has no ledger or documents to link (its sentinel slug
      # wouldn't resolve), so it just shows the empty structure.
      @allocations = sample_preview? ? [] : @event_registration.allocations.includes(:source).order(:created_at)
      @document_cards = sample_preview? ? [] : payment_document_cards
    end

    # Certificate of completion: the certificate once unlocked, otherwise the
    # pending unlock conditions.
    def certificate
      # The page shows the certificate once unlocked, or the pending unlock
      # conditions until then, so there's nothing to gate here.
    end

    # Add-to-LinkedIn page: the button that pre-fills the member's LinkedIn
    # certifications form, shown once the facilitator-training certificate unlocks.
    # Same gate as the certificate card; the sample preview bypasses it.
    def linkedin_badge
      return if sample_preview?
      redirect_to(registration_ticket_path(@event_registration.slug)) unless linkedin_badge_available?
    end

    # Scholarship status: the award (amount, funder, criteria, tasks) once a
    # scholarship exists, or a pending state while it is only requested. Nothing
    # to show when neither requested nor received.
    def scholarship
      unless @event_registration.scholarship_requested? || @event_registration.scholarship?
        redirect_to registration_ticket_path(@event_registration.slug)
        return
      end

      @scholarship = @event_registration.scholarships.first
      @form_responses_available = @event.registration_form&.form_submissions&.exists?(person: @event_registration.registrant)
    end

    # Records the recipient agreeing, from their scholarship page, to complete the
    # scholarship's tasks. The Agree button submits agreement=yes, which stamps
    # agreement_signed_at via the model.
    def sign_agreement
      scholarship = @event_registration.scholarships.first
      unless scholarship
        redirect_to registration_scholarship_path(@event_registration.slug)
        return
      end

      if params[:agreement] == "yes"
        scholarship.update!(agreement_signed: true) unless scholarship.agreement_signed?
        redirect_to registration_scholarship_path(@event_registration.slug), notice: "Thanks — your agreement has been recorded."
      else
        redirect_to registration_scholarship_path(@event_registration.slug), alert: "Something went wrong recording your agreement. Please try again."
      end
    end

    # CE hours status: hours, amount owed, and license number. The heading and the
    # requirements copy live on the materialized ce_hours callout row now.
    def ce
      @ce_callout = @event.registration_ticket_callouts.find_by(builtin_key: "ce_hours")
      case params[:checkout]
      when "success"
        flash.now[:notice] = "Your CE payment was successful."
      when "cancelled"
        flash.now[:alert] = "CE payment was cancelled. You can try again whenever you're ready."
      end
    end

    # Pay the CE balance via Stripe Checkout.
    def pay_ce
      ce_registration = @event_registration.continuing_education_registrations.first
      unless ce_registration&.remaining_cost&.positive?
        redirect_to registration_ce_path(@event_registration.slug), alert: "No CE payment is due."
        return
      end

      redirect_to_ce_stripe_checkout(ce_registration)
    end

    # Public license entry from the CE callout (type, number, issuing state, and
    # expiry). Edits the license on the registrant's (first) CE registration in
    # place, mirrors the number onto the registration's form answer, then returns to
    # the callout. Plain full-page POST — no Turbo. Shares
    # ContinuingEducationRegistration#assign_license with the admin edit page.
    def update_ce_license
      ce_registration = @event_registration.continuing_education_registrations.first
      return redirect_to(registration_ce_path(@event_registration.slug)) unless ce_registration

      # Once the certificate is issued the license is the credential it was issued
      # under — frozen here. Admins can still correct it on the admin CE edit page.
      if ce_registration.certificate_sent_at.present?
        return redirect_to registration_ce_path(@event_registration.slug),
          alert: "Your CE certificate has been issued, so the license can no longer be changed here. Contact us if it needs correcting."
      end

      ce_registration.assign_license(number: params[:license_number], kind: params[:license_kind],
                                     issuing_state: params[:license_issuing_state], expires_on: params[:license_expires_on])
      ce_registration.save!
      # assign_license already normalized the number; mirror the saved value rather
      # than re-stripping the raw param.
      record_ce_license_answer(ce_registration.professional_license.number)

      redirect_to registration_ce_path(@event_registration.slug), notice: "License saved."
    rescue ActiveRecord::RecordInvalid
      redirect_to registration_ce_path(@event_registration.slug), alert: "We couldn't save that license."
    end

    # Public CE opt-in from the callout: a registrant who didn't ask for credit at
    # registration can request it here. Sets the flag and creates the CE
    # registration (against a placeholder license; the number is entered next).
    def request_ce
      return redirect_to(registration_ce_path(@event_registration.slug)) unless @event.ce_eligible?

      unless @event_registration.continuing_education_registrations.exists?
        license = ProfessionalLicense.find_or_create_for(person: @event_registration.registrant)
        @event_registration.continuing_education_registrations.create!(professional_license: license)
      end

      redirect_to registration_ce_path(@event_registration.slug), notice: "Continuing education credit requested."
    end

    # Record the registrant signing in from their CE callout. Self-service and
    # public (no login), so created_by stays nil — only staff edits are attributed.
    # Gated on CE being paid in full and the day's sign-in window being open; a
    # second sign-in while already signed in is a no-op.
    def sign_in_ce
      return redirect_to(registration_ce_path(@event_registration.slug)) if sample_preview?
      unless attendance_enabled?
        return redirect_to registration_ce_path(@event_registration.slug), alert: "Signing in isn't available yet."
      end
      if @event_registration.signed_in?
        return redirect_to registration_ce_path(@event_registration.slug, anchor: "attendance"), notice: "You're already signed in."
      end
      unless @event.attendance_sign_in_open?
        return redirect_to registration_ce_path(@event_registration.slug, anchor: "attendance"),
          alert: "Sign-in is only open during the training day."
      end

      entry = @event_registration.event_attendance_time_entries.create!(signed_in_at: Time.current)
      redirect_to registration_ce_path(@event_registration.slug, anchor: "attendance"),
        notice: "Signed in at #{local_time(entry.signed_in_at)}."
    rescue ActiveRecord::RecordInvalid => e
      redirect_to registration_ce_path(@event_registration.slug, anchor: "attendance"),
        alert: e.record.errors.full_messages.to_sentence
    end

    # Close an open attendance entry. Not windowed — a forgotten sign-out can always
    # be recorded. Two cases: today's entry (stamped now) and the catch-up button for
    # a day the registrant left open (stamped that day's scheduled end) — see
    # #sign_out_target.
    def sign_out_ce
      return redirect_to(registration_ce_path(@event_registration.slug)) if sample_preview?
      entry, signed_out_at = sign_out_target
      unless entry
        return redirect_to registration_ce_path(@event_registration.slug, anchor: "attendance"), alert: "You're not signed in."
      end

      entry.update!(signed_out_at: signed_out_at)
      redirect_to registration_ce_path(@event_registration.slug, anchor: "attendance"), notice: sign_out_notice(entry)
    rescue ActiveRecord::RecordInvalid => e
      redirect_to registration_ce_path(@event_registration.slug, anchor: "attendance"),
        alert: e.record.errors.full_messages.to_sentence
    end

    # The registrant editing their own sign-in/out times for one training day. The
    # buttons above are only a shortcut for stamping "now" — the times themselves stay
    # editable, so someone who arrived before signing in, or never tapped the buttons
    # at all, can write the day up afterwards. Deliberately not windowed: the point is
    # to fix a day after it's over. Left unattributed, like the buttons.
    def update_ce_attendance
      return redirect_to(registration_ce_path(@event_registration.slug)) if sample_preview?
      unless attendance_enabled?
        return redirect_to registration_ce_path(@event_registration.slug), alert: "Editing your times isn't available yet."
      end

      date = AttendanceDayRows.date_from(params[:date])
      return head :unprocessable_content unless date

      rows = AttendanceDayRows.new(params, date)
      EventAttendanceEntriesUpdate.new(@event_registration, rows.entry_attributes, editor: nil).save!
      redirect_to registration_ce_path(@event_registration.slug, anchor: "attendance"),
        notice: "Your times for #{date.strftime("%a, %b %-d")} were saved."
    rescue ActiveRecord::RecordInvalid => e
      flash[:alert] = error_sentence(e.record)
      # Hand the typed times back so a rejected save doesn't cost the registrant what
      # they entered; the day reopens in edit mode prefilled with them.
      flash[:attendance_rows] = rows.submitted
      # ce_id names which licence's sheet was open, so the editor reopens on that one
      # rather than on every sheet at once.
      redirect_to registration_ce_path(@event_registration.slug, edit: date.iso8601,
        ce_id: params[:ce_id].presence, anchor: "attendance")
    end

    # Handouts page: callout-card links to the training worksheet/handout
    # resources, in display order, each opening its own registrant resource page
    # (PDF preview + download, with a back-to-handouts eyebrow). Cards read their
    # subtitle from the materialized handouts callout's join rows.
    def handouts
      return redirect_to registration_ticket_path(@event_registration.slug) unless builtin_published?("handouts")
      callout = @event.registration_ticket_callouts.find_by(builtin_key: "handouts")
      @builtin_intro = callout&.description.presence
      @handout_cards = resource_cards_for(callout, icon: "fa-solid fa-file-pdf", return_to: "handouts")
    end

    # Registrant-facing page for a single Resource, shown in the shared callout
    # chrome: the PDF first-page preview and a download button. Reached from the
    # handouts/forms callouts so a registrant views a document without leaving the
    # ticket context. The page content shown under the title comes from the join
    # row on the callout the registrant arrived from.
    def resource
      @resource = Resource.find(params[:resource_id]).decorate
      @resource_page_content = origin_callout_link&.page_content.presence
    end

    # Videoconference page: the join link and add-to-calendar options.
    def videoconference
      @event = @event_registration.event.decorate
    end

    # "Meet the staff" roster: the event's staff as the same flip-cards the admin
    # staff page shows (shared _staff_cards partial). Reachable only when the
    # built-in is published; the admin sample preview bypasses that gate.
    def staff
      return redirect_to(registration_ticket_path(@event_registration.slug)) unless sample_preview? || builtin_published?("staff")

      @event = @event.decorate
      @event_staffs = @event.event_staffs
        .includes(person: [ :sectors, { categorizable_items: { category: :category_type } }, { avatar_attachment: :blob }, { affiliations: :organization } ])
        .ordered_by_name
    end

    # FAQ for the training, with a folded-in contact link. Only reachable when
    # the event shows the FAQ callout. Renders the editable FAQ callout copy (the
    # admin edits it like every other callout, using the <toggle> syntax for each
    # question). The default questions are hydrated onto the row when it's
    # materialized (seeded from BuiltinCallouts.faq_html), so a blanked
    # description shows blank.
    def faq
      return redirect_to(registration_ticket_path(@event_registration.slug)) unless builtin_published?("faq")
      callout = @event.registration_ticket_callouts.find_by(builtin_key: "faq")
      @faq_content = callout&.description
    end

    private

    # Attendance sign-in/out follows the CE payment — it's the CE sign-in sheet. Any-of
    # rather than all-of, matching the callout view: each paid CE registration renders
    # its own sheet, and since they all record the same hours, one paid licence is
    # enough to let the registrant write those hours down.
    def attendance_enabled?
      @event_registration.ce_attendance_offered?
    end

    # A datetime rendered in the app zone as "9:02 AM", for sign-in/out flash notices.
    def local_time(time)
      helpers.attendance_clock_time(time)
    end

    # Which open entry this sign-out closes, and the time to stamp it with. The
    # catch-up button names an earlier day's entry explicitly (?entry_id) so it can't
    # be confused with today's — it lands on that day's scheduled end rather than now,
    # which would bank every hour since. Anything else closes today's entry at now.
    def sign_out_target
      return [ @event_registration.open_attendance_entry, Time.current ] if params[:entry_id].blank?

      forgotten = @event_registration.forgotten_sign_out_entry
      return [] unless forgotten && forgotten.id.to_s == params[:entry_id].to_s

      [ forgotten, @event_registration.forgotten_sign_out_at(forgotten) ]
    end

    # Name the day when the sign-out isn't for today, so a catch-up close reads as
    # what it is rather than looking like a stray time.
    def sign_out_notice(entry)
      time = local_time(entry.signed_out_at)
      return "Signed out at #{time}." if entry.attendance_date == Time.zone.today

      "Signed out for #{entry.attendance_date.strftime("%a, %b %-d")} at #{time}."
    end

    # Whether the event's built-in callout for this key is materialized and
    # published (visible). These public pages gate on that alone now — the admin's
    # published/hidden choice on the row decides whether the page is reachable, so
    # a hidden or not-yet-materialized card can't surface via a stray link.
    def builtin_published?(builtin_key)
      @event.registration_ticket_callouts.exists?(builtin_key: builtin_key, hidden: false)
    end

    # The badge is a facilitator-training credential, so it's reachable only on a
    # facilitator training whose certificate has unlocked (same gate as the card).
    def linkedin_badge_available?
      @event.facilitator_training? && @event_registration.certificate_available?
    end

    # Admin-only preview from the sample ticket. Renders these pages for an
    # unsaved, data-free sample registration instead of a real one looked up by
    # slug, so nothing is ever read from or written to a real registrant.
    def sample_preview?
      params[:sample].present?
    end

    def set_event_registration
      if sample_preview?
        @event = Event.find(params[:id])
        @event_registration = SampleTicketRegistration.new(@event, all_options: true).registration
      else
        @event_registration = EventRegistration.find_by!(slug: params[:slug])
      end
    end

    def authorize_callout
      if sample_preview?
        authorize! @event, to: :dashboard?
      else
        authorize! @event_registration, to: :show_public?
      end
    end

    def set_event
      @event ||= @event_registration.event
    end

    # The editable intro and linked resources for a built-in page, from the
    # materialized callout row for this action's builtin_key. Nil/empty when the
    # event hasn't materialized the card. Payment renders its own document list
    # (W-9 + invoice/receipt) in its Documents section, so it skips the generic
    # resource list here. Resources render as callout cards linking to their own
    # registrant page (PDF preview + download), each returning to this callout —
    # never inline.
    def set_builtin_content
      @builtin_callout = @event.registration_ticket_callouts.find_by(builtin_key: action_name)
      @builtin_intro = @builtin_callout&.description.presence
      callout = @builtin_callout
      callout = nil if action_name == "payment"
      @builtin_resource_cards = resource_cards_for(callout, icon: "fa-solid fa-file-lines", return_to: action_name)
    end

    # This registrant's cards for a callout's linked resources (nil callout → none).
    # Delegates to the shared decorator so every callout surface builds them the
    # same way — subtitle from the materialized join row, linking to the resource
    # page returning to this origin.
    def resource_cards_for(callout, icon:, return_to:)
      return [] unless callout
      callout.decorate.resource_cards(registrant_slug: @event_registration.slug, return_to:, icon:)
    end

    # The join row for @resource on the callout the registrant arrived from
    # (via return_to / callout_id), so the resource page can show that callout's
    # editable page content under the title.
    def origin_callout_link
      origin_callout&.registration_ticket_callout_resources&.find_by(resource_id: @resource.id)
    end

    def origin_callout
      case params[:return_to]
      when "callout"
        @event.registration_ticket_callouts.find_by(id: params[:callout_id])
      when *RegistrationTicketCallout::BUILTIN_KEYS
        @event.registration_ticket_callouts.find_by(builtin_key: params[:return_to])
      end
    end

    # Update form submission if ce record is updated via callout
    def record_ce_license_answer(number)
      form = @event.continuing_education_form
      field = form&.form_fields&.find_by(field_identifier: "ce_license_number")
      submission = form&.form_submissions&.find_by(person: @event_registration.registrant, role: "continuing_education")
      return unless field && submission

      answer = submission.form_answers.find_or_initialize_by(form_field: field)
      answer.update!(submitted_answer: number.to_s, question_name_when_answered: field.name)
    end

    # The payment page's Documents section as grey callout cards, rendered through
    # the shared card partial like every other callout surface: the dynamic
    # invoice/receipt first, then the payment callout's linked resources (the W-9
    # by default on paid events), each reading its admin-editable subtitle from the
    # materialized join row.
    def payment_document_cards
      slug = @event_registration.slug
      cards = []
      if @event_registration.invoice_available?
        cards << document_card(title: "Invoice", subtitle: "Itemized invoice for this registration",
          icon: "fa-solid fa-file-invoice-dollar", href: registration_invoice_path(slug, return_to: "payment"))
        # The receipt is proof money changed hands, so it links once an actual
        # payment settles the balance in full; until then (balance owing, or a
        # balance cleared only by scholarship/discount) it's a locked card.
        if @event_registration.receipt_available?
          cards << document_card(title: "Receipt", subtitle: "Paid-in-full receipt for this registration",
            icon: "fa-solid fa-receipt", href: registration_receipt_path(slug, return_to: "payment"))
        else
          cards << locked_document_card(title: "Receipt", icon: "fa-solid fa-receipt",
            subtitle: "Available once your payment is received in full")
        end
      end
      cards + payment_document_resources.map { |link| payment_resource_card(link, slug) }
    end

    # A payment-callout linked resource as a card. The W-9 only applies once an
    # actual payment is on file, so it renders locked (naming what unlocks it)
    # until then; every other document links straight through.
    def payment_resource_card(link, slug)
      if link.resource&.title == "W-9" && !@event_registration.w9_available?
        return locked_document_card(title: link.resource.title, icon: "fa-solid fa-file-pdf",
          subtitle: "Available once your payment is received")
      end
      link.decorate.to_card(registrant_slug: slug, return_to: "payment",
                            icon: "fa-solid fa-file-pdf", color: "gray")
    end

    # The payment callout's linked resource join rows (the W-9 by default on paid
    # events). Uses the materialized Payment row's links when present (so admins
    # can add/remove them), else transient links for the W-9 on paid events not
    # yet materialized.
    def payment_document_resources
      payment_callout = @event.registration_ticket_callouts.find_by(builtin_key: "payment")
      return payment_callout.registration_ticket_callout_resources.ordered.includes(:resource).to_a if payment_callout
      return [] unless @event.cost_cents.to_i.positive?
      Resource.where(title: "W-9").map { |resource| RegistrationTicketCalloutResource.new(resource:) }
    end

    # A grey document card for a non-resource payment document (the dynamic
    # invoice/receipt). Opens in a new tab, matching the callout-card contract.
    def document_card(title:, subtitle:, icon:, href:)
      BuiltinCalloutCards::Card.new(icon_class: icon, color: "gray", title:, subtitle:,
                                    href:, target: "_blank", trailing_icon: "fa-solid fa-arrow-right")
    end

    # A greyed-out, non-navigating card (no href) for a document that isn't
    # available yet; the payment view renders it as a plain div with a lock icon,
    # and the subtitle names what unlocks it.
    def locked_document_card(title:, subtitle:, icon:)
      BuiltinCalloutCards::Card.new(icon_class: icon, color: "gray", title:, subtitle:,
                                    href: nil, target: nil, trailing_icon: "fa-solid fa-lock")
    end

    def redirect_to_ce_stripe_checkout(ce_registration)
      person = @event_registration.registrant
      amount = ce_registration.remaining_cost

      person.set_payment_processor :stripe

      checkout_session = person.payment_processor.checkout(
        mode: "payment",
        metadata: {
          ce_registration_id: ce_registration.id,
          event_registration_id: @event_registration.id,
          event_id: @event.id
        },
        payment_intent_data: {
          metadata: {
            ce_registration_id: ce_registration.id,
            event_registration_id: @event_registration.id,
            event_id: @event.id
          },
          description: "CE Hours: #{@event.title}"
        },
        line_items: [ {
          price_data: {
            currency: "usd",
            product_data: { name: "CE Hours: #{@event.title}" },
            unit_amount: amount
          },
          quantity: 1
        } ],
        success_url: registration_ce_url(@event_registration.slug, checkout: "success"),
        cancel_url: registration_ce_url(@event_registration.slug, checkout: "cancelled")
      )

      @event_registration.update!(checkout_session_id: checkout_session.id)
      redirect_to checkout_session.url, allow_other_host: true, status: :see_other
    end
  end
end
