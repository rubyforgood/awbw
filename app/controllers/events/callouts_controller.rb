module Events
  # Public show pages for a registration ticket's magic callouts (payment, CE,
  # scholarship, forms, handouts, portal, videoconference, FAQ, certificate).
  # Each is reachable by the registration slug — the slug is the authorization,
  # so no login is required (mirrors the public ticket/invoice pages).
  class CalloutsController < ApplicationController
    skip_before_action :authenticate_user!
    before_action :set_event_registration
    before_action :authorize_callout
    before_action :set_event

    # Hidden Resource (by title) backing the handout links, in display order.
    # Missing ones (e.g. not seeded in an environment) are silently skipped.
    HANDOUT_RESOURCE_TITLES = [
      "2-Day AWBW Facilitator Training Worksheets & Handouts",
      "AWBW Training Workshop Worksheets",
      "AHA Moments",
      "Inviting and Responding to Participants' Sharing"
    ].freeze

    # Payment page: the full allocation ledger with the running balance due.
    def payment
      @allocations = @event_registration.allocations.includes(:source).order(:created_at)
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

    # CE hours status: requested hours, amount owed, and license number.
    def ce
    end

    # Forms page: callout-card links to the W-9 (when requested), invoice (when
    # requested), and the letter to supervisors resource — each opens in a new tab.
    def forms
      @form_cards = build_form_cards
    end

    # Handouts page: callout-card links to the training worksheet/handout
    # resources, in display order, each opening its own registrant resource page
    # (PDF preview + download, with a back-to-handouts eyebrow).
    def handouts
      by_title = Resource.where(title: HANDOUT_RESOURCE_TITLES).index_by(&:title)
      @handout_cards = HANDOUT_RESOURCE_TITLES.filter_map do |title|
        resource = by_title[title]
        next unless resource
        resource_card(icon: "fa-solid fa-file-pdf", title: resource.title,
                      subtitle: "Open this training resource",
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

    # Facilitator Portal access info, with a link to the home screen.
    def portal
    end

    # Videoconference page: the join link and add-to-calendar options.
    def videoconference
      @event = @event_registration.event.decorate
    end

    # FAQ for the training, with a folded-in contact link.
    def faq
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

    # Builds the callout-card links shown on the forms page. The W-9 and invoice
    # are always available; the letter to supervisors follows when seeded.
    def build_form_cards
      cards = [
        resource_card(icon: "fa-solid fa-file-pdf", title: "Download W-9",
                      subtitle: "AWBW's W-9 tax form for your records",
                      href: "/documents/awbw-w9.pdf", trailing_icon: "fa-solid fa-download"),
        resource_card(icon: "fa-solid fa-file-invoice-dollar", title: "View invoice",
                      subtitle: "Itemized invoice for this registration",
                      href: registration_invoice_path(@event_registration.slug, return_to: "forms"))
      ]
      letter = Resource.find_by(title: "Letter to Supervisors")
      if letter
        cards << resource_card(icon: "fa-solid fa-file-arrow-down", title: "Letter to supervisors",
                               subtitle: "Share to request release time",
                               href: registration_resource_path(@event_registration.slug, letter, return_to: "forms"), target: nil)
      end
      cards
    end

    # A blue callout card linking to a document. External/static links open in a
    # new tab (target: "_blank"); registrant resource pages stay in-tab so the
    # back-to-ticket eyebrow works (pass target: nil).
    def resource_card(icon:, title:, subtitle:, href:, target: "_blank", trailing_icon: "fa-solid fa-arrow-right")
      MagicTicketCallouts::Card.new(icon_class: icon, color: "blue", title: title, subtitle: subtitle,
                                    href: href, target: target, trailing_icon: trailing_icon)
    end
  end
end
