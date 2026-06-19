module Events
  class RegistrationsController < ApplicationController
    before_action :authenticate_user!, only: [ :create, :destroy ]
    before_action :set_event, only: [ :create, :destroy ]
    before_action :set_registrant, only: [ :create, :destroy ]
    before_action :set_event_registration, only: [ :show, :invoice, :scholarship, :faq,
      :payment, :certificate, :ce, :forms, :handouts, :portal, :videoconference,
      :resend_confirmation, :cancel, :reactivate, :pay ]

    # Hidden Resource (by title) backing the handout links on the handouts page,
    # in display order. Missing ones (e.g. not seeded in an environment) are
    # silently skipped.
    HANDOUT_RESOURCE_TITLES = [
      "2-Day AWBW Facilitator Training Worksheets & Handouts",
      "AWBW Training Workshop Worksheets",
      "AHA Moments",
      "Inviting and Responding to Participants' Sharing"
    ].freeze

    def show
      authorize! @event_registration, to: :show_public?

      if @event_registration.checkout_session_id.present? &&
         !@event_registration.payment_unresolved?
        checkout_session = Stripe::Checkout::Session.retrieve(@event_registration.checkout_session_id)
        @checkout_payment_status = checkout_session.payment_status
      end

      case params[:checkout]
      when "success"
        flash.now[:notice] = "Your payment was successful! You are registered for this event."
      when "cancelled"
        flash.now[:alert] = "Payment was cancelled. You are registered for this event but payment may still be due."
      end
    end

    def invoice
      authorize! @event_registration, to: :show_public?
      @event = @event_registration.event
      @invoice = EventInvoice.from_registration(@event_registration)
    end

    # Public status page for the registrant's scholarship, linked from the magic
    # ticket callout. Shows the award (amount, funder, criteria, tasks) once a
    # scholarship exists, or a pending state while it is only requested. When the
    # registrant has neither requested nor received one there is nothing to show.
    def scholarship
      authorize! @event_registration, to: :show_public?

      unless @event_registration.scholarship_requested? || @event_registration.scholarship?
        redirect_to registration_ticket_path(@event_registration.slug)
        return
      end

      @event = @event_registration.event
      @scholarship = @event_registration.scholarships.first
    end

    # Public FAQ page for the training, linked from the always-present "Frequently
    # asked questions" magic callout.
    def faq
      authorize! @event_registration, to: :show_public?
      @event = @event_registration.event
    end

    # Payment page: the full allocation ledger with the running balance due.
    def payment
      authorize! @event_registration, to: :show_public?
      @event = @event_registration.event
      @allocations = @event_registration.allocations.includes(:source).order(:created_at)
    end

    # Certificate of completion, rendered like the invoice. Only reachable once
    # the certificate is unlocked.
    def certificate
      authorize! @event_registration, to: :show_public?

      unless @event_registration.certificate_available?
        redirect_to registration_ticket_path(@event_registration.slug)
        return
      end

      @event = @event_registration.event
    end

    # CE hours status: requested hours, amount owed, and license number.
    def ce
      authorize! @event_registration, to: :show_public?
      @event = @event_registration.event
    end

    # Forms page: callout-card links to the W-9 (when requested), invoice (when
    # requested), and the letter to supervisors resource — each opens in a new tab.
    def forms
      authorize! @event_registration, to: :show_public?
      @event = @event_registration.event
      @form_cards = build_form_cards
    end

    # Handouts page: callout-card links to the training worksheet/handout
    # resources, in display order, each opening in a new tab.
    def handouts
      authorize! @event_registration, to: :show_public?
      @event = @event_registration.event
      by_title = Resource.where(title: HANDOUT_RESOURCE_TITLES).index_by(&:title)
      @handout_cards = HANDOUT_RESOURCE_TITLES.filter_map do |title|
        resource = by_title[title]
        next unless resource
        resource_card(icon: "fa-solid fa-file-pdf", title: resource.title,
                      subtitle: "Open this training resource", href: resource_path(resource))
      end
    end

    # Facilitator Portal access info, with a link to the home screen.
    def portal
      authorize! @event_registration, to: :show_public?
      @event = @event_registration.event
    end

    # Videoconference page: the join link and add-to-calendar options.
    def videoconference
      authorize! @event_registration, to: :show_public?
      @event = @event_registration.event.decorate
    end

    def resend_confirmation
      authorize! @event_registration, to: :show_public?
      send_registration_notifications(@event_registration)
      redirect_to registration_ticket_path(@event_registration.slug), notice: "Confirmation email sent."
    end

    def cancel
      authorize! @event_registration, to: :show_public?

      if @event_registration.active?
        @event_registration.update!(status: "cancelled")
        redirect_to registration_ticket_path(@event_registration.slug), notice: "Your registration has been cancelled."
      else
        redirect_to registration_ticket_path(@event_registration.slug), alert: "Registration is already cancelled."
      end
    end

    def reactivate
      authorize! @event_registration, to: :show_public?

      if @event_registration.status == "cancelled"
        @event_registration.update!(status: "registered")
        redirect_to registration_ticket_path(@event_registration.slug), notice: "Your registration has been reactivated."
      else
        redirect_to registration_ticket_path(@event_registration.slug), alert: "Registration is not cancelled."
      end
    end

    def pay
      authorize! @event_registration, to: :show_public?

      unless @event_registration.remaining_cost > 0
        redirect_to registration_ticket_path(@event_registration.slug), alert: "No payment is due."
        return
      end

      @event = @event_registration.event
      redirect_to_stripe_checkout(@event_registration)
    end

    def create
      existing = @event.event_registrations.find_by(registrant: @registrant)

      if existing&.status == "cancelled"
        authorize! existing
        existing.update!(status: "registered")
        send_registration_notifications(existing)
        success = "Your registration has been reactivated."
        if requires_payment?(existing)
          redirect_to_stripe_checkout(existing)
        else
          respond_to do |format|
            format.turbo_stream { flash.now[:notice] = success }
            format.html { redirect_to registration_ticket_path(existing.slug), notice: success }
          end
        end
        return
      end

      @event_registration = @event.event_registrations.new(registrant: @registrant)
      authorize! @event_registration

      if @event_registration.save
        if requires_payment?(@event_registration)
          redirect_to_stripe_checkout(@event_registration)
        else
          send_registration_notifications(@event_registration)
          success = "You have successfully registered for this event."
          respond_to do |format|
            format.turbo_stream { flash.now[:notice] = success }
            format.html { redirect_to registration_ticket_path(@event_registration.slug), notice: success }
          end
        end
      else
        error = @event_registration.errors.full_messages.to_sentence
        respond_to do |format|
          format.turbo_stream { flash.now[:alert] = error }
          format.html { redirect_to @event, alert: error }
        end
      end
    end

    def destroy
      @event_registration = @event.event_registrations.find_by(registrant: @registrant)

      unless @event_registration
        skip_verify_authorized!
        alert = "Registration not found"
        respond_to do |format|
          format.turbo_stream { flash.now[:alert] = alert }
          format.html { redirect_to @event, alert: alert }
        end
        return
      end

      authorize! @event_registration

      if @event_registration.destroy
        success = "You are no longer registered."
        respond_to do |format|
          format.turbo_stream { flash.now[:notice] = success }
          format.html { redirect_to @event, notice: success }
        end
      else
        error = @event_registration.errors.full_messages.to_sentence
        respond_to do |format|
          format.turbo_stream { flash.now[:alert] = error }
          format.html { redirect_to @event, alert: error }
        end
      end
    end

    private

    # Builds the callout-card links shown on the forms page. W-9 and invoice only
    # appear when the registrant requested them; the letter to supervisors is a
    # shared resource shown whenever it has been seeded.
    def build_form_cards
      cards = []
      if @event_registration.w9_requested?
        cards << resource_card(icon: "fa-solid fa-file-pdf", title: "Download W-9",
                               subtitle: "AWBW's W-9 tax form for your records",
                               href: "/documents/awbw-w9.pdf", trailing_icon: "fa-solid fa-download")
      end
      if @event_registration.invoice_requested?
        cards << resource_card(icon: "fa-solid fa-file-invoice-dollar", title: "View invoice",
                               subtitle: "Itemized invoice for this registration",
                               href: registration_invoice_path(@event_registration.slug))
      end
      letter = Resource.find_by(title: "Letter to Supervisors")
      if letter
        cards << resource_card(icon: "fa-solid fa-file-arrow-down", title: "Letter to supervisors",
                               subtitle: "Share to request release time", href: resource_path(letter))
      end
      cards
    end

    # A blue, new-tab callout card linking to an external/resource document.
    def resource_card(icon:, title:, subtitle:, href:, trailing_icon: "fa-solid fa-arrow-up-right-from-square")
      MagicTicketCallouts::Card.new(icon_class: icon, color: "blue", title: title, subtitle: subtitle,
                                    href: href, target: "_blank", trailing_icon: trailing_icon)
    end

    def send_registration_notifications(event_registration)
      registrant_email = event_registration.registrant.preferred_email
      return if registrant_email.blank?

      NotificationServices::CreateNotification.call(
        noticeable: event_registration,
        kind: :event_registration_confirmation,
        recipient_role: :person,
        recipient_email: registrant_email,
        notification_type: 0
      )

      NotificationServices::CreateNotification.call(
        noticeable: event_registration,
        kind: :event_registration_confirmation_fyi,
        recipient_role: :admin,
        recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
        notification_type: 0
      )
    end

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_registrant
      if params[:registrant_id]
        @registrant = Person.find(params[:registrant_id])
      else
        @registrant = current_user.person || create_person_for_current_user
      end
    end

    def create_person_for_current_user
      person = Person.create!(
        first_name: current_user.first_name,
        last_name: current_user.last_name,
        email: current_user.email,
        created_by: current_user,
        updated_by: current_user
      )
      current_user.update!(person: person)
      person
    end

    def set_event_registration
      @event_registration = EventRegistration.find_by!(slug: params[:slug])
    end

    def requires_payment?(registration)
      @event.cost_cents.to_i > 0 && registration.remaining_cost > 0
    end

    def redirect_to_stripe_checkout(registration)
      person = registration.registrant
      amount = registration.remaining_cost

      person.set_payment_processor :stripe

      checkout_session = person.payment_processor.checkout(
        mode: "payment",
        metadata: { event_registration_id: registration.id, event_id: @event.id },
        payment_intent_data: {
          metadata: { event_registration_id: registration.id, event_id: @event.id },
          description: "Training Fee: #{@event.title}"
        },
        line_items: [ {
          price_data: {
            currency: "usd",
            product_data: { name: "Registration: #{@event.title}" },
            unit_amount: amount
          },
          quantity: 1
        } ],
        success_url: registration_ticket_url(registration.slug, checkout: "success"),
        cancel_url: registration_ticket_url(registration.slug, checkout: "cancelled")
      )
      registration.update!(checkout_session_id: checkout_session.id)
      redirect_to checkout_session.url, allow_other_host: true, status: :see_other
    end
  end
end
