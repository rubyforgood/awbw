class StoryImportsController < ApplicationController
  # Admin-only flow for importing stories from a WordPress Posts Export CSV.
  #
  #   new     → upload form
  #   create  → dry-run preview of what would be created (nothing written)
  #   confirm → run the real import against the stashed file
  #
  # The uploaded CSV is stashed as an ActiveStorage blob between the preview
  # and confirm steps (it is too large for the cookie session). The blob is
  # purged once the import runs.

  def new
    authorize! Story, to: :import?
  end

  def create
    authorize! Story, to: :import?

    file = params[:file]
    return redirect_to(new_story_import_path, alert: "Choose a CSV file to import.") if file.blank?
    return redirect_to(new_story_import_path, alert: "That file is not a CSV.") unless csv?(file)

    @filename = file.original_filename
    @blob = ActiveStorage::Blob.create_and_upload!(
      io: file.open, filename: @filename, content_type: "text/csv"
    )
    @result = run_import(file.path, dry_run: true)
    render :create
  rescue CSV::MalformedCSVError, ArgumentError => e
    @blob&.purge
    redirect_to new_story_import_path, alert: "Could not read that CSV: #{e.message}"
  end

  def confirm
    authorize! Story, to: :import?

    blob = ActiveStorage::Blob.find_signed!(params[:signed_id])
    result = blob.open { |tempfile| run_import(tempfile.path, dry_run: false) }
    blob.purge

    redirect_to stories_path, notice: import_notice(result)
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    redirect_to new_story_import_path,
                alert: "That upload is no longer available — please choose the file again."
  end

  private

  def run_import(path, dry_run:)
    StoryImporter.new(csv_path: path, import_user: current_user, dry_run: dry_run).call
  end

  def csv?(file)
    file.original_filename.to_s.downcase.end_with?(".csv") ||
      file.content_type.to_s.in?(%w[text/csv application/csv application/vnd.ms-excel])
  end

  def import_notice(result)
    "Import complete — #{result.ideas_created} story ideas and " \
      "#{result.stories_created} connected stories created" \
      "#{" (#{result.skipped.size} rows skipped)" if result.skipped.any?}."
  end
end
