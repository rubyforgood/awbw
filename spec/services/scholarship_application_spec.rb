require "rails_helper"

RSpec.describe ScholarshipApplication do
  let(:event) { create(:event) }
  let(:person) { create(:person) }

  subject(:application) { described_class.new(event: event, person: person) }

  context "with a dedicated scholarship form and its own scholarship submission" do
    let(:scholarship_form) { create(:form, :scholarship) }
    let(:question) do
      create(:form_field, form: scholarship_form, section: "scholarship",
             name: "How much can you contribute?", answer_type: :free_form_input_one_line)
    end

    before do
      create(:event_form, event: event, form: scholarship_form, role: "scholarship")
      submission = create(:form_submission, :with_event, event: event, person: person,
                          form: scholarship_form, role: "scholarship")
      create(:form_answer, form_submission: submission, form_field: question, submitted_answer: "$250")
    end

    it "surfaces the answer paired with its question" do
      expect(application).to be_answered
      expect(application.answer_pairs).to contain_exactly([ question, have_attributes(submitted_answer: "$250") ])
      expect(application.submission.role).to eq("scholarship")
    end
  end

  context "with the answers stored on the registration submission (answered while registering)" do
    let(:registration_form) { create(:form, name: "Registration Form") }
    let(:scholarship_form) { create(:form, :scholarship) }
    let(:question) do
      create(:form_field, form: scholarship_form, section: "scholarship",
             name: "Why do you need a scholarship?", answer_type: :free_form_input_paragraph)
    end

    before do
      create(:event_form, event: event, form: registration_form, role: "registration")
      create(:event_form, event: event, form: scholarship_form, role: "scholarship")
      # Answer hangs off the registration submission, but on a scholarship-form field.
      reg_submission = create(:form_submission, :with_event, event: event, person: person, form: registration_form)
      create(:form_answer, form_submission: reg_submission, form_field: question, submitted_answer: "Limited budget")
    end

    it "still finds the scholarship answer across the person's submissions" do
      expect(application).to be_answered
      expect(application.answer_pairs).to contain_exactly([ question, have_attributes(submitted_answer: "Limited budget") ])
      expect(application.answers_by_field_id[question.id].submitted_answer).to eq("Limited budget")
    end
  end

  context "with a scholarship section embedded in the registration form (no dedicated form)" do
    let(:registration_form) { create(:form, name: "Registration Form") }
    let(:question) do
      create(:form_field, form: registration_form, section: "scholarship",
             name: "Describe your need", answer_type: :free_form_input_paragraph)
    end

    before do
      create(:event_form, event: event, form: registration_form, role: "registration")
      submission = create(:form_submission, :with_event, event: event, person: person, form: registration_form)
      create(:form_answer, form_submission: submission, form_field: question, submitted_answer: "I have a need")
    end

    it "surfaces the embedded-section answer" do
      expect(application).to be_answered
      expect(application.answer_pairs).to contain_exactly([ question, have_attributes(submitted_answer: "I have a need") ])
    end
  end

  context "without any scholarship answers" do
    let(:registration_form) { create(:form, name: "Registration Form") }

    before do
      create(:event_form, event: event, form: registration_form, role: "registration")
      create(:form_field, form: registration_form, section: "scholarship", name: "Need?")
      create(:form_submission, :with_event, event: event, person: person, form: registration_form)
    end

    it "is not answered but still reports the registration submission" do
      expect(application).not_to be_answered
      expect(application.answer_pairs.map(&:last)).to all(be_nil)
      expect(application.submission).to be_present
    end
  end
end
