module CalloutFormsHelper
  # Whether a callout's linked form renders open, ready to fill: opened (not
  # dripping), not completed anonymously, and unsubmitted or being edited — the
  # last branch of _callout_form. Pages fold their own copy while one is open so
  # the form comes first.
  def callout_form_fillable?(callout_form, submission:, anonymously_completed:, editing:)
    !callout_form.dripping? && !anonymously_completed && (submission.nil? || editing)
  end
end
