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

  def name
    "#{question_name_when_answered.presence || form_field&.name}: #{submitted_answer}"
  end
end
