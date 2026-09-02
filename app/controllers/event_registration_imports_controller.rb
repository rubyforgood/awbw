class EventRegistrationImportsController < ApplicationController
  # Admin-only flow for bulk-importing attended registrants into one event from a
  # CSV.
  #
  #   new     → pick the event + upload form
  #   create  → dry-run preview of what would be created (nothing written)
  #   confirm → run the real import against the stashed file
  #
  # The uploaded file is stashed as an ActiveStorage blob between the preview and
  # confirm steps (too large for the cookie session), and purged once the import
  # runs. The chosen event id travels through the preview's hidden fields so
  # confirm can reopen the blob.

  def new
    authorize! EventRegistration, to: :import?
    @events = importable_events
    @event = Event.find_by(id: params[:event_id])
  end

  def create
    authorize! EventRegistration, to: :import?
    @events = importable_events
    @event = Event.find_by(id: params[:event_id])
    file = params[:file]

    return render_new_error("Choose an event to import into.") if @event.nil?
    return render_new_error(missing_form_message) unless EventRegistrationImporter.importable?(@event)
    return render_new_error("Choose a CSV file to import.") if file.blank?
    return render_new_error("That file must be a .csv.") unless supported?(file)

    @filename = file.original_filename
    begin
      @blob = ActiveStorage::Blob.create_and_upload!(io: file.open, filename: @filename)
      @result = run_import(file.path, dry_run: true)
    rescue => e
      @blob&.purge
      return render_new_error("Could not read that file: #{e.message}")
    end
    # Rendering (not redirecting) on a POST: Turbo only displays non-redirect form
    # responses when the status is 4xx/5xx, so the preview needs 422.
    render :create, status: :unprocessable_content
  end

  def confirm
    authorize! EventRegistration, to: :import?
    @event = Event.find(params[:event_id])
    blob = ActiveStorage::Blob.find_signed!(params[:signed_id])
    result = blob.open do |tempfile|
      run_import(tempfile.path, dry_run: false, source: blob.filename.to_s)
    end
    blob.purge

    redirect_to registrants_event_path(@event), notice: import_notice(result)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to new_event_registration_import_path,
                alert: "That upload is no longer available — please choose the file again."
  end

  private

  def run_import(path, dry_run:, source: @filename)
    EventRegistrationImporter.call(
      file_path: path, event: @event,
      import_user: current_user, source: source, dry_run: dry_run
    )
  end

  def importable_events
    Event.order(start_date: :desc)
  end

  def supported?(file)
    extension_for(file).in?(EventRegistrationImporter::SUPPORTED_EXTENSIONS)
  end

  def extension_for(file)
    File.extname(file.original_filename.to_s).delete(".").downcase
  end

  def render_new_error(message)
    flash.now[:alert] = message
    render :new, status: :unprocessable_content
  end

  def missing_form_message
    "“#{@event.title}” has no registration form with an organization field, so imported " \
      "registrants couldn't be reconciled. Add one to the event first."
  end

  def import_notice(result)
    "Import complete — #{result.registrations_created} attended registrations created " \
      "(#{result.people_created} new people, #{result.people_matched} matched)" \
      "#{", #{result.registrations_promoted} promoted to attended" if result.registrations_promoted.positive?}" \
      "#{", #{result.organizations_to_reconcile} orgs to reconcile" if result.organizations_to_reconcile.positive?}" \
      "#{", #{result.payments_recorded} payments (#{helpers.dollars_from_cents(result.payments_amount_cents)})" if result.payments_recorded.positive?}" \
      "#{", #{result.skipped.size} rows skipped" if result.skipped.any?}."
  end
end
