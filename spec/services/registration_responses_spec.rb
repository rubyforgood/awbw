require "rails_helper"

RSpec.describe RegistrationResponses do
  let(:event) { create(:event) }
  let(:person) { create(:person) }
  let(:reg_form) { create(:form, name: "Reg form") }
  let(:scholarship_form) { create(:form, name: "Scholarship form") }
  let(:ce_form) { create(:form, name: "CE form") }
  let(:need) { create(:form_field, form: scholarship_form, name: "Why do you need a scholarship?") }
  let(:license) { create(:form_field, form: ce_form, name: "License number") }
  let(:start) { Time.zone.local(2026, 9, 1, 10) }

  before do
    create(:event_form, :registration, event: event, form: reg_form)
    create(:event_form, :scholarship, event: event, form: scholarship_form)
    create(:event_form, event: event, form: ce_form, role: "continuing_education")
  end

  def submit(form, at, answers = {})
    create(:form_submission, person: person, event: event, form: form, role: nil, created_at: at).tap do |submission|
      answers.each { |field, value| submission.form_answers.create!(form_field: field, submitted_answer: value) }
    end
  end

  it "gives each application its own registration, scholarship, and CE answers, newest first" do
    first = submit(reg_form, start)
    submit(scholarship_form, start + 1.second, need => "Budget cut")
    submit(ce_form, start + 2.seconds, license => "42111")
    second = submit(reg_form, start + 30.days)
    submit(ce_form, start + 30.days + 1.second, license => "99999")

    newest, earliest = described_class.new(event: event, person: person).sittings

    expect(newest.registration).to eq(second)
    expect(newest.scholarship).to be_nil
    expect(newest.continuing_education.responses[license.id].submitted_answer).to eq("99999")
    expect(earliest.registration).to eq(first)
    expect(earliest.scholarship.responses[need.id].submitted_answer).to eq("Budget cut")
    expect(earliest.continuing_education.responses[license.id].submitted_answer).to eq("42111")
    expect(earliest.form_names).to eq("Reg form + Scholarship form + CE form")
  end

  it "leaves out other events' submissions" do
    submit(reg_form, start)
    create(:form_submission, person: person, event: create(:event), form: reg_form, created_at: start + 1.day)

    expect(described_class.new(event: event, person: person).sittings.size).to eq(1)
  end
end
