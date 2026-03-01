class ShortEventRegistrationFormBuilder < BaseRegistrationFormBuilder
  FORM_NAME = "Short Event Registration"

  def self.build_standalone!
    form = Form.create!(name: FORM_NAME)
    new.build_fields!(form)
    form
  end

  def self.build!(event)
    form = Form.create!(name: FORM_NAME)
    new.build_fields!(form)
    EventForm.create!(event: event, form: form, role: "registration") if event
    form
  end

  def build_fields!(form)
    position = 0

    position = build_basic_contact_fields(form, position)
    position = build_consent_fields(form, position)
    position = build_qualitative_fields(form, position)
    position = build_scholarship_fields(form, position)

    position
  end

  private

  def build_qualitative_fields(form, position)
    position = add_field(form, position, "How did you hear about this event?", :multiple_choice_checkbox,
                         key: "referral_source", group: "qualitative", required: true,
                         options: [ "AWBW Email", "Facebook", "Instagram", "LinkedIn", "Online Search", "Word of Mouth", "Other" ])

    position = add_field(form, position, "Are you interested in learning more about upcoming trainings or resources?",
                         :multiple_choice_checkbox,
                         key: "training_interest", group: "qualitative", required: true,
                         options: [ "Yes", "Not right now" ])

    position
  end
end
