module Admin
  # Certificate-of-completion settings: upload the artwork the certificate pages
  # otherwise read from hand-created, exact-title hidden Resources — the optional
  # full-bleed frame override for each certificate category (live training,
  # on-demand, other events) and the two signature strips (training + CE). Each is
  # a global default: a frame overrides the committed/default design when present,
  # and the signatures fill the signature line. The artwork lives on admin-managed,
  # hidden-from-search Resources (matched by title) so it's managed in-app rather
  # than committed to this public repo.
  class CertificateSettingsController < ApplicationController
    # slot key => the details used to look up / label its backing Resource.
    SLOTS = {
      training_frame: { title: Resource::CERTIFICATE_FRAME_TITLES[:training],
                        label: "Facilitator training frame",
                        description: "Full-bleed frame for the live facilitator-training certificate. Falls back to the built-in painted border when empty." },
      on_demand_frame: { title: Resource::CERTIFICATE_FRAME_TITLES[:on_demand],
                         label: "On-demand training frame",
                         description: "Full-bleed frame for on-demand (self-paced) facilitator-training certificates. On-demand certificates never show signatures." },
      ce_frame: { title: Resource::CE_CERTIFICATE_FRAME_TITLE,
                  label: "CE certificate frame",
                  description: "Full-bleed frame for the CE Confirmation of Attendance certificate. Falls back to the default purple/gold design when empty." },
      other_frame: { title: Resource::CERTIFICATE_FRAME_TITLES[:other],
                     label: "Other events frame",
                     description: "Full-bleed frame for every non-training event certificate. Falls back to the default purple/gold design when empty." },
      training_signatures: { title: Resource::TRAINING_CERTIFICATE_SIGNATURES_TITLE,
                             label: "Facilitator training signatures",
                             description: "Signature strip shown on the live facilitator-training certificate only — not on-demand or other events." },
      ce_signatures: { title: Resource::CE_CERTIFICATE_SIGNATURE_TITLE,
                       label: "CE certificate signature",
                       description: "The CE administrator's signature on the CE Confirmation of Attendance certificate." }
    }.freeze

    def show
      authorize! :certificate_settings
      @slots = SLOTS.map { |key, config| slot_view(key, config) }
    end

    def update
      authorize! :certificate_settings
      config = SLOTS[params[:slot]&.to_sym]
      return redirect_to(admin_certificate_settings_path, alert: "Unknown setting.", status: :see_other) unless config

      resource = slot_resource(config[:title])
      return remove_artwork(resource, config) if params[:remove] == "1"

      attach_artwork(resource, config)
    end

    private

    def attach_artwork(resource, config)
      file = params[:file]
      return redirect_to(admin_certificate_settings_path, alert: "Choose an image to upload.", status: :see_other) if file.blank?

      asset = resource.primary_asset || resource.build_primary_asset
      asset.file.attach(file)
      if resource.save
        redirect_to admin_certificate_settings_path, notice: "#{config[:label]} updated.", status: :see_other
      else
        redirect_to admin_certificate_settings_path, alert: resource.errors.full_messages.to_sentence, status: :see_other
      end
    end

    def remove_artwork(resource, config)
      resource.primary_asset&.file&.purge_later
      redirect_to admin_certificate_settings_path, notice: "#{config[:label]} removed.", status: :see_other
    end

    # The hidden-from-search Resource backing a slot, created on first upload.
    def slot_resource(title)
      Resource.find_or_create_by!(title: title) do |resource|
        resource.kind = "Resource"
        resource.hidden_from_search = true
        resource.published = false
      end
    end

    def slot_view(key, config)
      resource = Resource.find_by(title: config[:title])
      {
        key: key,
        label: config[:label],
        description: config[:description],
        file: resource&.signature_file
      }
    end
  end
end
