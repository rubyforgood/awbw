# `submitted_answer` is stored verbatim — exactly what the applicant typed — so
# their words are never silently altered (e.g. "revenue < $5k" or "C++ <T>"
# survive intact). It is NOT HTML-sanitized on write.
#
# Safety is enforced at render time instead: every place that displays an answer
# uses plain `<%= %>`, which auto-escapes, so any markup shows as inert text.
# Do NOT render a submitted_answer through `raw`, `html_safe`, `<%==`, or
# `simple_format` — that would reintroduce an XSS hole. Volume abuse (giant
# answers) is bounded separately by FormField's effective max-characters cap.
class FormAnswer < ApplicationRecord
  belongs_to :form_field, optional: true
  belongs_to :form_submission

  # A file-upload answer stores its file on a polymorphic Asset (the same
  # attachment/validation/display machinery story ideas use). Text answers leave
  # this nil; submitted_answer still holds the filename so every text-only
  # display and export shows something readable.
  has_one :asset, as: :owner, dependent: :destroy

  def name
    "#{question_name_when_answered.presence || form_field&.name}: #{submitted_answer}"
  end

  # The attached upload, when this answer is a file-upload answer with a file on
  # file. nil for text answers or an unanswered file question. The attachment is
  # authoritative for a file answer — submitted_answer only caches its name (see
  # #sync_uploaded_filename!).
  def uploaded_file
    file = asset&.file
    file if file&.attached?
  end

  # Refresh the cached filename from the attachment. Every writer of a file
  # answer's submitted_answer should go through here so the two can't drift —
  # they did once, when a blank file param cleared the name off an answer whose
  # file was still attached, and the presence checks that read submitted_answer
  # (ScholarshipApplication#answered?, the scholarship card) then read the
  # question as unanswered.
  def sync_uploaded_filename!
    update!(submitted_answer: uploaded_file&.filename.to_s)
  end
end
