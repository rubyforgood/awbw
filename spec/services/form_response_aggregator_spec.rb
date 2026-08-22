require "rails_helper"

RSpec.describe FormResponseAggregator do
  let(:form) { create(:form, :standalone) }

  def answer(submission, field, value)
    create(:form_answer, form_submission: submission, form_field: field, submitted_answer: value)
  end

  describe "summary figures" do
    it "counts submissions, distinct respondents, and input questions" do
      person = create(:person)
      create(:form_field, form: form, name: "Color", answer_type: :single_select_radio)
      create(:form_field, form: form, name: "Section", answer_type: :group_header, required: false)

      create(:form_submission, form: form, person: person)
      create(:form_submission, form: form, person: person)
      create(:form_submission, form: form)

      aggregator = described_class.new(form)

      expect(aggregator.submission_count).to eq(3)
      expect(aggregator.respondent_count).to eq(2)
      expect(aggregator.question_count).to eq(1)
      expect(aggregator.any_submissions?).to be(true)
    end

    it "reports no submissions for an untouched form" do
      expect(described_class.new(form).any_submissions?).to be(false)
    end
  end

  describe "select questions" do
    it "tallies option counts sorted by frequency and charts a small set as a pie" do
      field = create(:form_field, form: form, name: "Color", answer_type: :single_select_radio)
      answer(create(:form_submission, form: form), field, "Blue")
      answer(create(:form_submission, form: form), field, "Blue")
      answer(create(:form_submission, form: form), field, "Red")

      report = described_class.new(form).field_reports.first

      expect(report.kind).to eq(:select)
      expect(report.rows).to eq([ [ "Blue", 2 ], [ "Red", 1 ] ])
      expect(report.answered_count).to eq(3)
      expect(report.chart).to eq(:pie)
      expect(report.multi).to be(false)
    end

    it "splits multi-select answers and charts them as a bar" do
      field = create(:form_field, form: form, name: "Interests", answer_type: :multi_select_checkbox)
      answer(create(:form_submission, form: form), field, "Art, Music")
      answer(create(:form_submission, form: form), field, "Art")

      report = described_class.new(form).field_reports.first

      expect(report.rows).to eq([ [ "Art", 2 ], [ "Music", 1 ] ])
      expect(report.answered_count).to eq(2)
      expect(report.multi).to be(true)
      expect(report.chart).to eq(:bar)
    end

    it "groups 'Other: <text>' answers under the base option and surfaces the write-ins" do
      field = create(:form_field, form: form, name: "Source", answer_type: :single_select_radio)
      create(:form_field_answer_option, form_field: field, answer_option: create(:answer_option, name: "Other"))
      answer(create(:form_submission, form: form), field, "Other: Facebook")
      answer(create(:form_submission, form: form), field, "Other: Twitter")

      report = described_class.new(form).field_reports.first

      expect(report.rows).to eq([ [ "Other", 2 ] ])
      expect(report.specify_rows).to contain_exactly([ "Facebook", 1 ], [ "Twitter", 1 ])
    end

    it "resolves sector ids to names" do
      sector = create(:sector, name: "Healthcare")
      field = create(:form_field, form: form, name: "Sector", answer_type: :multi_select_checkbox,
                                  field_identifier: "additional_sectors")
      answer(create(:form_submission, form: form), field, sector.id.to_s)

      report = described_class.new(form).field_reports.first

      expect(report.rows).to eq([ [ "Healthcare", 1 ] ])
    end
  end

  describe "geographic questions" do
    it "charts a state field as a US map, regardless of answer type" do
      field = create(:form_field, form: form, name: "State", answer_type: :free_form_input_one_line,
                                  field_identifier: "mailing_state")
      answer(create(:form_submission, form: form), field, "California")
      answer(create(:form_submission, form: form), field, "California")
      answer(create(:form_submission, form: form), field, "Texas")

      report = described_class.new(form).field_reports.first

      expect(report.kind).to eq(:map)
      expect(report.chart).to eq(:map)
      expect(report.rows).to eq([ [ "California", 2 ], [ "Texas", 1 ] ])
    end

    it "charts a country field as a world map" do
      field = create(:form_field, form: form, name: "Country", answer_type: :single_select_dropdown,
                                  field_identifier: "organization_country")
      answer(create(:form_submission, form: form), field, "Canada")

      report = described_class.new(form).field_reports.first

      expect(report.kind).to eq(:map)
      expect(report.chart).to eq(:world_map)
    end
  end

  describe "free-text questions" do
    it "lists the actual answers newest-first with their submitter" do
      field = create(:form_field, form: form, name: "Thoughts", answer_type: :free_form_input_paragraph)
      alice = create(:person, first_name: "Alice", last_name: "A")
      older = create(:form_submission, form: form, person: alice, created_at: 2.days.ago)
      newer = create(:form_submission, form: form, created_at: 1.hour.ago)
      answer(older, field, "First answer")
      answer(newer, field, "Second answer")

      report = described_class.new(form).field_reports.first

      expect(report.kind).to eq(:text)
      expect(report.responses.map(&:text)).to eq([ "Second answer", "First answer" ])
      expect(report.responses.last.person_name).to eq(alice.name)
      expect(report.answered_count).to eq(2)
    end

    it "ignores blank answers" do
      field = create(:form_field, form: form, name: "Thoughts", answer_type: :free_form_input_paragraph)
      answer(create(:form_submission, form: form), field, "   ")

      report = described_class.new(form).field_reports.first

      expect(report.responses).to be_empty
      expect(report.answered_count).to eq(0)
    end
  end

  describe "file-upload questions" do
    it "counts uploaded files" do
      field = create(:form_field, :file_upload, form: form, name: "Resume")
      answer(create(:form_submission, form: form), field, "resume.pdf")
      answer(create(:form_submission, form: form), field, "")

      report = described_class.new(form).field_reports.first

      expect(report.kind).to eq(:file)
      expect(report.answered_count).to eq(1)
    end
  end

  it "reports questions in form order" do
    create(:form_field, form: form, name: "Second", answer_type: :single_select_radio, position: 2)
    create(:form_field, form: form, name: "First", answer_type: :free_form_input_one_line, position: 1)

    labels = described_class.new(form).field_reports.map(&:label)

    expect(labels).to eq([ "First", "Second" ])
  end
end
