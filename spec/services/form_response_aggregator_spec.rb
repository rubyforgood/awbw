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

  describe "numeric questions" do
    def number_field(name)
      create(:form_field, form: form, name: name,
             answer_type: :free_form_input_one_line, input_type: :number_integer)
    end

    it "averages and totals a whole-number field as an open count" do
      field = number_field("Adults served")
      answer(create(:form_submission, form: form), field, "10")
      answer(create(:form_submission, form: form), field, "25")

      report = described_class.new(form).field_reports.first

      expect(report.kind).to eq(:number)
      expect(report.answered_count).to eq(2)
      expect(report.total).to eq(35)
      expect(report.average).to eq(17.5)
      expect(report.minimum).to eq(10)
      expect(report.maximum).to eq(25)
      expect(report.integer_valued).to be(true)
    end

    it "drops blank and non-numeric answers from the figures" do
      field = number_field("Teens served")
      answer(create(:form_submission, form: form), field, "50")
      answer(create(:form_submission, form: form), field, "")
      answer(create(:form_submission, form: form), field, "n/a")

      report = described_class.new(form).field_reports.first

      expect(report.answered_count).to eq(1)
      expect(report.total).to eq(50)
    end

    it "reports zero answered with a nil average before anyone responds" do
      number_field("Elders served")

      report = described_class.new(form).field_reports.first

      expect(report.kind).to eq(:number)
      expect(report.answered_count).to eq(0)
      expect(report.average).to be_nil
    end

    it "keeps decimals for a number_decimal field" do
      field = create(:form_field, form: form, name: "Average rating",
                     answer_type: :free_form_input_one_line, input_type: :number_decimal)
      answer(create(:form_submission, form: form), field, "4.5")
      answer(create(:form_submission, form: form), field, "3.0")

      report = described_class.new(form).field_reports.first

      expect(report.total).to eq(7.5)
      expect(report.average).to eq(3.75)
      expect(report.integer_valued).to be(false)
    end
  end

  it "reports questions in form order" do
    create(:form_field, form: form, name: "Second", answer_type: :single_select_radio, position: 2)
    create(:form_field, form: form, name: "First", answer_type: :free_form_input_one_line, position: 1)

    labels = described_class.new(form).field_reports.map(&:label)

    expect(labels).to eq([ "First", "Second" ])
  end

  describe "event scoping" do
    it "narrows the rollup to one event's submissions when given an event_id" do
      event = create(:event)
      field = create(:form_field, form: form, name: "Color", answer_type: :single_select_radio)
      answer(create(:form_submission, form: form, event: event), field, "Blue")
      answer(create(:form_submission, form: form, event: create(:event)), field, "Red")

      aggregator = described_class.new(form, event_id: event.id)

      expect(aggregator.submission_count).to eq(1)
      expect(aggregator.field_reports.first.rows).to eq([ [ "Blue", 1 ] ])
    end

    it "rolls up every submission when no event_id is given" do
      field = create(:form_field, form: form, name: "Color", answer_type: :single_select_radio)
      answer(create(:form_submission, form: form, event: create(:event)), field, "Blue")
      answer(create(:form_submission, form: form, event: create(:event)), field, "Red")

      expect(described_class.new(form).submission_count).to eq(2)
      expect(described_class.new(form, event_id: nil).submission_count).to eq(2)
    end
  end

  describe "question name filtering" do
    before do
      create(:form_field, form: form, name: "Favorite color", answer_type: :single_select_radio, position: 1)
      create(:form_field, form: form, name: "Favorite food", answer_type: :single_select_radio, position: 2)
      create(:form_submission, form: form)
    end

    it "reports only the questions whose name matches, case-insensitively" do
      labels = described_class.new(form, question_query: "COLOR").field_reports.map(&:label)
      expect(labels).to eq([ "Favorite color" ])
    end

    it "still counts every question in the Questions total" do
      aggregator = described_class.new(form, question_query: "color")
      expect(aggregator.field_reports.size).to eq(1)
      expect(aggregator.question_count).to eq(2)
    end

    it "reports every question when the query is blank" do
      expect(described_class.new(form, question_query: "  ").field_reports.size).to eq(2)
    end
  end
end
