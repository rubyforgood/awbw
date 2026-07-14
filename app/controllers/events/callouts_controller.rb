module Events
  # Public show pages for a registration ticket's magic callouts (payment, CE,
  # scholarship, handouts, videoconference, FAQ, certificate).
  # Each is reachable by the registration slug — the slug is the authorization,
  # so no login is required (mirrors the public ticket/invoice pages).
  class CalloutsController < ApplicationController
    skip_before_action :authenticate_user!
    before_action :set_event_registration
    before_action :authorize_callout
    before_action :set_event
    # These pages carry an editable intro (the built-in row's "Callout page text")
    # above the app-controlled content, plus any resources linked to the row.
    before_action :set_builtin_content, only: %i[ payment scholarship certificate videoconference ]

    # Hidden Resource (by title) backing the handout links, in display order.
    # Missing ones (e.g. not seeded in an environment) are silently skipped.
    HANDOUT_RESOURCE_TITLES = [
      "2-Day AWBW Facilitator Training Worksheets & Handouts",
      "AWBW Training Workshop Worksheets",
      "Aha Moments",
      "Inviting and Responding to Participants' Sharing",
      "Letter to Supervisors"
    ].freeze

    HANDOUT_SUBTITLES = {
      "2-Day AWBW Facilitator Training Worksheets & Handouts" =>
        "List of resources and worksheets we will reference and utilize during the training. You do not need to print them out, it may be helpful for you to access the links during the training.",
      "AWBW Training Workshop Worksheets" =>
        "Worksheets you can create on during all 5 of the art workshops at the training. Any art materials are welcomed during creation.",
      "Aha Moments" =>
        "Worksheet you can use to reflect on the workshop, its impact, and how you'd like to apply it.",
      "Inviting and Responding to Participants' Sharing" =>
        "A resource to invite and support sharing, active listening, and connection during breakout rooms.",
      "Letter to Supervisors" =>
        "Letter you can share to help relieve you from competing responsibilities during the two training days. So you can secure the time and space needed to fully engage in the training."
    }.freeze

    # Payment page: the full allocation ledger with the running balance due, plus
    # the linked documents (the W-9 from the payment callout's resources, and the
    # dynamic invoice/receipt) for paid events.
    def payment
      @allocations = @event_registration.allocations.includes(:source).order(:created_at)
      @document_resources = payment_document_resources
    end

    # Certificate of completion, rendered like the invoice. Only reachable once
    # the certificate is unlocked.
    def certificate
      unless @event_registration.certificate_available?
        redirect_to registration_ticket_path(@event_registration.slug)
      end
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

    # CE hours status: hours, amount owed, and license number.
    def ce
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

    # Handouts page: callout-card links to the training worksheet/handout
    # resources, in display order, each opening its own registrant resource page
    # (PDF preview + download, with a back-to-handouts eyebrow).
    def handouts
      return redirect_to registration_ticket_path(@event_registration.slug) unless @event.show_handouts_callout?
      by_title = Resource.where(title: HANDOUT_RESOURCE_TITLES).index_by(&:title)
      @handout_cards = HANDOUT_RESOURCE_TITLES.filter_map do |title|
        resource = by_title[title]
        next unless resource
        resource_card(icon: "fa-solid fa-file-pdf", title: resource.title,
                      subtitle: HANDOUT_SUBTITLES[resource.title] || "Open this training resource",
                      href: registration_resource_path(@event_registration.slug, resource, return_to: "handouts"), target: nil)
      end
    end

    # Registrant-facing page for a single Resource, shown in the shared callout
    # chrome: the PDF first-page preview and a download button. Reached from the
    # handouts/forms callouts so a registrant views a document without leaving the
    # ticket context.
    def resource
      @resource = Resource.find(params[:resource_id]).decorate
    end

    # Videoconference page: the join link and add-to-calendar options.
    def videoconference
      @event = @event_registration.event.decorate
    end

    # FAQ for the training, with a folded-in contact link. Only reachable when
    # the event shows the FAQ callout.
    def faq
      redirect_to registration_ticket_path(@event_registration.slug) unless @event.show_faq_callout?
    end

    private

    def set_event_registration
      @event_registration = EventRegistration.find_by!(slug: params[:slug])
    end

    def authorize_callout
      authorize! @event_registration, to: :show_public?
    end

    def set_event
      @event = @event_registration.event
    end

    # The editable intro and linked resources for a built-in page, from the
    # materialized callout row for this action's magic_key. Nil/empty when the
    # event hasn't materialized the card. Payment renders its own document list
    # (W-9 + invoice/receipt) in its Documents section, so it skips the generic
    # resource list here. Resources render as callout cards linking to their own
    # registrant page (PDF preview + download), each returning to this callout —
    # never inline.
    def set_builtin_content
      callout = @event.registration_ticket_callouts.find_by(magic_key: action_name)
      @builtin_intro = callout&.description.presence
      resources = callout && action_name != "payment" ? callout.resources.to_a : []
      @builtin_resource_cards = resources.map do |resource|
        resource_card(icon: "fa-solid fa-file-lines", title: resource.title,
                      subtitle: "Open this document",
                      href: registration_resource_path(@event_registration.slug, resource, return_to: action_name), target: nil)
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

    # The payment callout's linked documents (the W-9 by default on paid events),
    # shown on the payment page's Documents section. Uses the materialized Payment
    # row's resources when present (so admins can add/remove them), else the W-9
    # for paid events not yet materialized.
    def payment_document_resources
      payment_callout = @event.registration_ticket_callouts.find_by(magic_key: "payment")
      return payment_callout.resources.to_a if payment_callout
      @event.cost_cents.to_i.positive? ? Resource.where(title: "W-9").to_a : []
    end

    # A blue callout card linking to a document. External/static links open in a
    # new tab (target: "_blank"); registrant resource pages stay in-tab so the
    # back-to-ticket eyebrow works (pass target: nil).
    def resource_card(icon:, title:, subtitle:, href:, target: "_blank", trailing_icon: "fa-solid fa-arrow-right")
      MagicTicketCallouts::Card.new(icon_class: icon, color: "blue", title: title, subtitle: subtitle,
                                    href: href, target: target, trailing_icon: trailing_icon)
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
