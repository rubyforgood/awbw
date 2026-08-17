# Shared answer-persistence for the public form-submission flows — event
# registration (EventRegistrationServices::PublicRegistration) and standalone
# public forms (PublicFormSubmission). Persists each submitted field's answer
# onto a submission, attaching file-upload blobs to the answer's Asset. The
# file-upload path is hardened against forged, stale, and oversized uploads (see
# #upload_attachable and Asset's own content-type/size validation), so every
# public submission flow goes through here rather than reimplementing it.
module FormAnswerPersistence
  # Raised when a file-upload answer's value isn't a usable upload — a tampered,
  # stale, or otherwise unverifiable direct-upload signed id. Callers rescue it so
  # the respondent gets a form error instead of an unhandled exception.
  UnreadableUpload = Class.new(StandardError)

  UNREADABLE_UPLOAD_MESSAGE = "We couldn't read one of your uploaded files. Please choose it again.".freeze

  private

  # Save one field's answer. File-upload fields attach their blob to the answer's
  # Asset; everything else stores the (comma-joined) text.
  def persist_answer(submission, field, raw_value)
    record = submission.form_answers.find_or_initialize_by(form_field: field)
    record.question_name_when_answered = field.name

    if field.file_upload?
      attach_uploaded_file(record, raw_value)
    else
      record.update!(submitted_answer: answer_text(raw_value))
    end
  end

  def answer_text(raw_value)
    raw_value.is_a?(Array) ? raw_value.reject(&:blank?).join(", ") : raw_value.to_s
  end

  # Attach the uploaded blob (a direct-upload signed id, or an uploaded file) to
  # the answer's Asset. The answer row is saved first so the polymorphic owner id
  # resolves; submitted_answer then caches the filename so text-only views,
  # exports, and notifications still read. Asset enforces the content type and
  # size on save, rolling back the whole submission on a rejected file.
  def attach_uploaded_file(record, raw_value)
    # An untouched file input still posts a blank value, so blank means "no new
    # upload" — keep the file, and its filename, the answer already has.
    record.sync_uploaded_filename!
    return if raw_value.blank?

    # Named explicitly: assets.type defaults to "PrimaryAsset", which accepts only
    # images, so a bare build_asset would reject every document type the upload
    # field offers.
    asset = record.asset || record.build_asset(type: FormUploadAsset.name)
    asset.file.attach(upload_attachable(raw_value))
    asset.save!
    record.sync_uploaded_filename!
  end

  # A direct upload arrives as a signed blob id. Handing the raw string to
  # `attach` resolves it with find_signed!, which raises InvalidSignature or
  # RecordNotFound on a tampered or stale id — neither is rescued here, so a
  # forged param would 500 a public endpoint. Resolve it leniently instead and
  # turn a miss into a form error. Anything else (a multipart UploadedFile, when
  # the direct-upload JS didn't run) attaches as-is.
  def upload_attachable(raw_value)
    return raw_value unless raw_value.is_a?(String)

    ActiveStorage::Blob.find_signed(raw_value) || raise(UnreadableUpload, UNREADABLE_UPLOAD_MESSAGE)
  end
end
