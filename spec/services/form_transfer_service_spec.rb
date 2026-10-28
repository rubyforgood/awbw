require "rails_helper"

RSpec.describe FormTransferService do
  let(:form) { create(:form, name: "Registration", role: "registration", header: "<p>Welcome</p>", anonymous: false) }
  let!(:facilitator) { create(:form_field, form: form, name: "Are you a facilitator?", position: 1, field_identifier: "facilitator") }
  let!(:since) { create(:form_field, form: form, name: "Since when?", position: 2, parent_id: facilitator.id) }
  let(:worksheet) { create(:resource, title: "Worksheet") }

  before do
    facilitator.form_field_answer_options.create!(option_name: "Yes")
    facilitator.form_field_answer_options.create!(option_name: "No")
    since.form_field_resources.create!(resource: worksheet)
  end

  def payload(form_ids = nil)
    described_class.console_script(form_ids)[/import\("([^"]+)"\)/, 1]
  end

  def copy_of(name) = Form.find_by(name: "FROM TEST: #{name}")

  describe ".simulated_name" do
    it "abbreviates production" do
      expect(described_class.simulated_name("Registration", "production")).to eq("FROM PROD: Registration")
      expect(described_class.simulated_name("Registration", "staging")).to eq("FROM STAGING: Registration")
    end
  end

  describe ".console_script" do
    it "prints one line carrying just the given forms" do
      other = create(:form, name: "Other")

      script = described_class.console_script([ form.id ])

      expect(script.lines.size).to eq(1)
      expect(script).to end_with("# copy of 1 form from test")
      expect(described_class.decode(payload([ form.id ]))["forms"].keys).to eq([ form.id.to_s ])
      expect(described_class.decode(payload)["forms"].keys).to include(form.id.to_s, other.id.to_s)
    end
  end

  describe ".import" do
    it "builds a copy named for the source environment, with its questions, options, and resources" do
      script = payload([ form.id ])

      expect { described_class.import(script) }.to output(/created form #\d+ "FROM TEST: Registration": 2 questions, 0 updated questions, 2 answer options/).to_stdout

      copy = copy_of("Registration")
      expect(copy).to have_attributes(role: "registration", header: "<p>Welcome</p>", published: false)
      fields = copy.form_fields.order(:position)
      expect(fields.map(&:name)).to eq([ "Are you a facilitator?", "Since when?" ])
      expect(fields.first.answer_options.map(&:name)).to eq(%w[Yes No])
      expect(fields.second.parent_id).to eq(fields.first.id)
      expect(fields.second.resources).to contain_exactly(worksheet)
      expect(form.reload.name).to eq("Registration")
    end

    it "refreshes an earlier copy to match the source, keeping its id, extra questions, and answers" do
      script = payload([ form.id ])
      expect { described_class.import(script) }.to output.to_stdout
      copy = copy_of("Registration")
      copied = copy.form_fields.find_by(field_identifier: "facilitator")
      copied.update!(name: "Facilitator?", required: false)
      copied.form_field_answer_options.joins(:answer_option).where(answer_options: { name: "No" }).destroy_all
      copy.form_fields.find_by(name: "Since when?").destroy!
      create(:form_field, form: copy, name: "Allergies", position: 3)
      copy.update!(header: "<p>Old</p>")
      answer = create(:form_answer, form_field: copied)

      expect { described_class.import(script) }.to output(/refreshed form ##{copy.id} .*: 1 question, 1 updated question, 1 answer option/).to_stdout

      expect(copy.reload.header).to eq("<p>Welcome</p>")
      expect(copy.form_fields.order(:position, :id).map(&:name)).to eq([ "Are you a facilitator?", "Since when?", "Allergies" ])
      expect(copied.reload).to have_attributes(required: true)
      expect(copied.answer_options.map(&:name)).to contain_exactly("Yes", "No")
      expect(copy.form_fields.find_by(name: "Since when?").parent_id).to eq(copied.id)
      expect(answer.reload.form_field).to eq(copied)
    end

    it "reports a resource it can't find and builds the rest" do
      script = payload([ form.id ])
      worksheet.update!(title: "Renamed")

      expect { described_class.import(script) }.to output(/! Resource "Worksheet" not found — skipped/).to_stdout
      expect(copy_of("Registration").form_fields.count).to eq(2)
    end
  end

  describe ".compare" do
    it "says when the copy isn't there yet, without building it" do
      expect { described_class.compare(payload([ form.id ])) }
        .to output("+ \"FROM TEST: Registration\" isn't here — import builds it\n").to_stdout
      expect(copy_of("Registration")).to be_nil
    end

    it "lists differing settings, questions, options, resources, and order" do
      form.update!(role: "general", anonymous: true)
      create(:form_field, form: form, name: "Anything else?", position: 3)
      script = payload([ form.id ])
      expect { described_class.import(script) }.to output.to_stdout
      copy = copy_of("Registration")
      copy.update!(anonymous: false)
      copied = copy.form_fields.find_by(field_identifier: "facilitator")
      copied.update!(name: "Facilitator?", required: false, position: 4)
      copied.form_field_answer_options.joins(:answer_option).where(answer_options: { name: "No" }).destroy_all
      copied.form_field_answer_options.create!(option_name: "Maybe")
      copy.form_fields.find_by(name: "Since when?").tap { |field| field.form_field_resources.destroy_all }.update!(parent_id: nil)
      copy.form_fields.find_by(name: "Anything else?").update!(name: "Comments")

      expect { described_class.compare(script) }.to output(<<~OUTPUT).to_stdout
        ~ Form ##{copy.id} "FROM TEST: Registration" differs:
            anonymous: source true, here false
            "Facilitator?": name: source "Are you a facilitator?", here "Facilitator?"
            "Facilitator?": required: source true, here false
            "Facilitator?": missing options No
            "Facilitator?": extra options Maybe
            "Since when?": follows a different question
            "Since when?": missing resources Worksheet
            missing question "Anything else?"
            extra question "Comments"
            questions are in a different order
      OUTPUT
    end
  end
end
