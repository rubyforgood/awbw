require "rails_helper"

RSpec.describe SurveyFormSeeder do
  it "creates the survey template forms with their roles" do
    expect { described_class.call }.to change(Form, :count).by(4)

    expect(Form.find_by(name: "Day 1 Survey").role).to eq("day_1_survey")
    expect(Form.find_by(name: "Day 2 Survey").role).to eq("day_2_survey")
    expect(Form.find_by(name: "Post-Event Survey").role).to eq("post_event_survey")
    expect(Form.find_by(name: "Post-Training Recipients Survey").role).to eq("recipient_survey")
  end

  it "populates each form with fields from its presets" do
    described_class.call

    expect(Form.find_by(name: "Day 1 Survey").form_fields).to be_present
  end

  it "is idempotent on form name and reports only what it created" do
    described_class.call

    result = nil
    expect { result = described_class.call }.not_to change(Form, :count)
    expect(result).to be_empty
  end

  it "reports the names it created" do
    expect(described_class.call).to contain_exactly(
      "Day 1 Survey", "Day 2 Survey", "Post-Event Survey", "Post-Training Recipients Survey"
    )
  end

  describe "fan-out resource links" do
    # The clarity Part One question, matched by prompt + subtitle (no identifier).
    def part_one_field
      Form.find_by(name: "Day 1 Survey").form_fields
          .find_by(name: FormBuilderService::CLARITY_PROMPT, subtitle: "Day 1 — Part One")
    end

    it "links a fan-out question to its topic resources when they exist" do
      touchstone = create(:resource, title: "The Touchstone Journey")
      described_class.call

      expect(part_one_field.resources).to include(touchstone)
      expect(part_one_field.per_resource?).to be(true)
    end

    it "links the growth questions over the day's workshops" do
      SurveyFormSeeder::DAY_1_WORKSHOPS.each { |title| create(:resource, title:) }
      described_class.call

      growth = Form.find_by(name: "Day 1 Survey").form_fields.find_by(name: FormBuilderService::GROWTH_PERSONAL_PROMPT)
      expect(growth.resources.map(&:title)).to match_array(SurveyFormSeeder::DAY_1_WORKSHOPS)
    end

    it "skips a topic whose resource isn't present, and is idempotent" do
      described_class.call
      expect(part_one_field.resources).to be_empty

      create(:resource, title: "The Touchstone Journey")
      expect { described_class.new.link_fanout_resources }.to change { part_one_field.reload.resources.count }.by(1)
      expect { described_class.new.link_fanout_resources }.not_to change { part_one_field.reload.resources.count }
    end
  end
end
