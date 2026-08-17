# Shared answer-persistence for the public submission flows (event registration
# and standalone public forms). The file-upload path is hardened against forged,
# stale, and oversized uploads (see #upload_attachable), so both flows reuse it
# rather than reimplementing it.
module FormAnswerPersistence
  # Raised when a file-upload value isn't a usable upload (tampered/stale signed
  # id); callers rescue it into a form error rather than a 500.
  UnreadableUpload = Class.new(StandardError)

  UNREADABLE_UPLOAD_MESSAGE = "We couldn't read one of your uploaded files. Please choose it again.".freeze

  private

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

  def attach_uploaded_file(record, raw_value)
    # An untouched file input posts blank — keep the file the answer already has.
    record.sync_uploaded_filename!
    return if raw_value.blank?

    # Named type: assets.type defaults to PrimaryAsset (images only), which would
    # reject the document types this field offers.
    asset = record.asset || record.build_asset(type: FormUploadAsset.name)
    asset.file.attach(upload_attachable(raw_value))
    asset.save!
    record.sync_uploaded_filename!
  end

  # Resolve a direct-upload signed id leniently: find_signed! would raise (and 500
  # a public endpoint) on a forged/stale id, so turn a miss into a form error. A
  # multipart UploadedFile (no direct-upload JS) attaches as-is.
  def upload_attachable(raw_value)
    return raw_value unless raw_value.is_a?(String)

    ActiveStorage::Blob.find_signed(raw_value) || raise(UnreadableUpload, UNREADABLE_UPLOAD_MESSAGE)
  end
end
