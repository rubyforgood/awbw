module Admin
  # Certificate-of-completion settings: connect a library Resource to each
  # certificate slot — the full-bleed frame for the facilitator-training,
  # on-demand, CE, and other-events certificates, plus the facilitator-training
  # and CE signature strips. The connected Resource is the global default the
  # certificate reads (a frame overrides the committed/default design; a signature
  # fills the signature line). The connection is stored on resources.certificate_role,
  # so the artwork lives on normal Resources rather than committed to this public
  # repo, served via a signed same-origin proxy on the certificate page.
  class CertificateSettingsController < ApplicationController
    # role => how the slot is labelled on the page.
    SLOTS = {
      "training_frame" => { label: "Facilitator training frame",
                            description: "Full-bleed frame for the live facilitator-training certificate. Falls back to the built-in painted border when empty.",
                            title: Resource::CERTIFICATE_FRAME_TITLES[:training],
                            builtin: "certificates/certificate-training-border.png" },
      "on_demand_frame" => { label: "On-demand training frame",
                             description: "Full-bleed frame for on-demand (self-paced) facilitator-training certificates. On-demand certificates never show signatures.",
                             title: Resource::CERTIFICATE_FRAME_TITLES[:on_demand],
                             builtin: "certificates/certificate-ondemand-border.png" },
      "ce_frame" => { label: "CE certificate frame",
                      description: "Full-bleed frame for the CE Confirmation of Attendance certificate. Falls back to the default purple/gold design when empty.",
                      title: Resource::CE_CERTIFICATE_FRAME_TITLE,
                      builtin_css: true },
      "other_frame" => { label: "Other events frame",
                         description: "Full-bleed frame for every non-training event certificate. Falls back to the default purple/gold design when empty.",
                         title: Resource::CERTIFICATE_FRAME_TITLES[:other],
                         builtin_css: true },
      "training_signatures" => { label: "Facilitator training signatures",
                                 description: "Signature strip shown on the live facilitator-training certificate only — not on-demand or other events.",
                                 title: Resource::TRAINING_CERTIFICATE_SIGNATURES_TITLE },
      "ce_signatures" => { label: "CE certificate signature",
                           description: "The CE administrator's signature on the CE Confirmation of Attendance certificate.",
                           title: Resource::CE_CERTIFICATE_SIGNATURE_TITLE }
    }.freeze

    def show
      authorize! :certificate_settings
      @slots = SLOTS.map { |role, config| slot_view(role, config) }
    end

    def update
      authorize! :certificate_settings
      role = params[:slot].to_s
      config = SLOTS[role]
      return redirect_to(admin_certificate_settings_path, alert: "Unknown setting.", status: :see_other) unless config

      return disconnect(role, config) if params[:remove] == "1"

      resource = Resource.find_by(id: params[:resource_id])
      return redirect_to(admin_certificate_settings_path, alert: "Choose a resource to connect.", status: :see_other) unless resource

      connect(resource, role)
      redirect_to admin_certificate_settings_path, notice: "#{config[:label]} connected to “#{resource.title}”.", status: :see_other
    end

    private

    # One resource per role: clear whoever holds it (the unique index forbids two),
    # then stamp the chosen one.
    def connect(resource, role)
      Resource.transaction do
        Resource.where(certificate_role: role).where.not(id: resource.id).find_each do |held|
          held.update!(certificate_role: nil)
        end
        resource.update!(certificate_role: role)
      end
    end

    def disconnect(role, config)
      Resource.where(certificate_role: role).find_each { |held| held.update!(certificate_role: nil) }
      redirect_to admin_certificate_settings_path, notice: "#{config[:label]} disconnected.", status: :see_other
    end

    def slot_view(role, config)
      resource = Resource.find_by(certificate_role: role)
      {
        role: role,
        label: config[:label],
        description: config[:description],
        title: config[:title],
        builtin: config[:builtin],
        builtin_css: config[:builtin_css],
        resource: resource,
        file: resource&.signature_file
      }
    end
  end
end
