class ScholarshipApplicationFormBuilder < BaseRegistrationFormBuilder
  FORM_NAME = "Scholarship Application"

  def self.build_standalone!
    form = Form.create!(name: FORM_NAME, scholarship_application: true)
    new.build_fields!(form)
    form
  end

  def self.build!(event)
    form = Form.create!(name: FORM_NAME, scholarship_application: true)
    new.build_fields!(form)
    EventForm.create!(event: event, form: form, role: "scholarship") if event
    form
  end

  def build_fields!(form)
    build_scholarship_fields(form, 0)
    form
  end
end
