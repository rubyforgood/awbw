module Admin
  # Connect the library Resource that fills each built-in role (Resource::ROLES):
  # the certificate frames and signature strips, the W-9, and the training
  # handouts. The connection is stored on resources.role, so the files live on
  # normal Resources rather than committed to this public repo.
  class ResourceRolesController < ApplicationController
    SECTIONS = {
      "Certificate artwork" => "Frames and the CE signature apply to every certificate of that type. The facilitator-training signature is the default for new events and can be swapped on an event's certificate callout.",
      "Payment documents" => "The default W-9 added to each new event's payment callout. Change it for one event in that event's callouts; existing events keep what they have.",
      "Training handouts" => "The default handouts added, in this order, to each new event's Handouts callout. Change them for one event in that event's callouts; existing events keep what they have."
    }.freeze

    # role => how the slot is labelled on the page.
    SLOTS = {
      "training_frame" => { section: "Certificate artwork", label: "Facilitator training frame",
                            description: "Full-bleed frame for the live facilitator-training certificate. Falls back to the built-in painted border when empty.",
                            preview_partial: "events/callouts/training_certificate", signature_role: "training_signatures" },
      "on_demand_frame" => { section: "Certificate artwork", label: "On-demand training frame",
                             description: "Full-bleed frame for on-demand (self-paced) facilitator-training certificates. On-demand certificates never show signatures.",
                             preview_partial: "events/callouts/ondemand_certificate" },
      "ce_frame" => { section: "Certificate artwork", label: "CE certificate frame",
                      description: "Full-bleed frame for the CE Confirmation of Attendance certificate. Falls back to the default purple/gold design when empty.",
                      preview_partial: "events/callouts/ce_confirmation_certificate", signature_role: "ce_signatures" },
      "other_frame" => { section: "Certificate artwork", label: "Other events frame",
                         description: "Full-bleed frame for every non-training event certificate. Falls back to the default purple/gold design when empty.",
                         preview_partial: "events/callouts/completion_certificate" },
      "training_signatures" => { section: "Certificate artwork", label: "Facilitator training signatures",
                                 description: "Signature strip shown on the live facilitator-training certificate only — not on-demand or other events.",
                                 image_preview: true },
      "ce_signatures" => { section: "Certificate artwork", label: "CE certificate signature",
                           description: "The CE administrator's signature on the CE Confirmation of Attendance certificate.",
                           image_preview: true },
      "w9" => { section: "Payment documents", label: "W-9",
                description: "AWBW's W-9 tax form, for registrants who need to set AWBW up as a vendor." },
      "training_handouts" => { section: "Training handouts", label: "2-day training worksheets & handouts",
                               description: "Worksheets referenced throughout the training." },
      "training_workshop_worksheets" => { section: "Training handouts", label: "Training workshop worksheets",
                                          description: "Create-along worksheets for the five art workshops." },
      "aha_moments" => { section: "Training handouts", label: "Aha moments",
                         description: "Worksheet to reflect on the workshop and its impact." },
      "participant_sharing_guide" => { section: "Training handouts", label: "Inviting and responding to participants' sharing",
                                       description: "Guidance for sharing and connection in breakout rooms." },
      "supervisor_letter" => { section: "Training handouts", label: "Letter to supervisors",
                               description: "Letter trainees share to secure time to fully engage in the training." }
    }.freeze

    def show
      authorize! :resource_roles
      @sections = SLOTS.map { |role, config| slot_view(role, config) }.group_by { |slot| slot[:section] }
      set_preview_sample
    end

    # The full-size certificate for one frame slot, with sample content, its frame,
    # and the signature it prints with.
    def preview
      authorize! :resource_roles
      role = params[:slot].to_s
      config = SLOTS[role]
      return redirect_to(admin_resource_roles_path, alert: "Unknown setting.", status: :see_other) unless config&.dig(:preview_partial)

      @slot = slot_view(role, config)
      @signature_file = Resource.for_role(config[:signature_role])&.signature_file if config[:signature_role]
      set_preview_sample
    end

    def update
      authorize! :resource_roles
      role = params[:slot].to_s
      config = SLOTS[role]
      return redirect_to(admin_resource_roles_path, alert: "Unknown setting.", status: :see_other) unless config

      # Clearing the picker (the ✕) submits a blank resource_id — treat it, and the
      # explicit remove, as a disconnect.
      return disconnect(role, config) if params[:remove] == "1" || params[:resource_id].blank?

      resource = Resource.find_by(id: params[:resource_id])
      return redirect_to(admin_resource_roles_path, alert: "We couldn't find that resource.", status: :see_other) unless resource

      connect(resource, role)
      redirect_to admin_resource_roles_path, notice: "#{config[:label]} connected to “#{resource.title}”.", status: :see_other
    rescue ActiveRecord::RecordNotUnique
      redirect_to admin_resource_roles_path, alert: "That slot just changed. Please try again.", status: :see_other
    end

    private

    def set_preview_sample
      @preview_event = Event.new(title: "Spring Facilitator Training",
                                 start_date: Date.new(2026, 3, 2), end_date: Date.new(2026, 3, 4)).decorate
      @preview_recipient = "Jordan Rivera"
    end

    # One resource per role: clear whoever holds it (the unique index forbids two),
    # then stamp the chosen one.
    def connect(resource, role)
      Resource.transaction do
        Resource.where(role:).where.not(id: resource.id).find_each { |held| assign_role(held, nil) }
        assign_role(resource, role)
      end
    end

    def disconnect(role, config)
      Resource.where(role:).find_each { |held| assign_role(held, nil) }
      redirect_to admin_resource_roles_path, notice: "#{config[:label]} disconnected.", status: :see_other
    end

    # The role is a pointer (SLOTS + the unique index guard it), so an older record's
    # unrelated validation gaps (no created_by, blank kind) must not block it. Skipping
    # validation also skips UserStampable, so the stamps are set here; callbacks still
    # run, so the change lands on the resource's change log.
    def assign_role(resource, role)
      resource.role = role
      resource.updated_by = current_user
      resource.created_by ||= current_user
      resource.save!(validate: false)
    end

    def slot_view(role, config)
      # The picker reflects only a role-connected resource, so a legacy title match
      # (which lookups still use as a fallback) never gets pre-selected and stuck —
      # the admin can always pick freely to override it. The effective resource
      # (role, else title match) drives the preview and caption.
      connected = Resource.find_by(role:)
      effective = connected || Resource.legacy_role_match(role)
      config.merge(
        role: role,
        connected_resource: connected,
        resource: effective,
        connected: connected.present?,
        file: effective&.signature_file
      )
    end
  end
end
