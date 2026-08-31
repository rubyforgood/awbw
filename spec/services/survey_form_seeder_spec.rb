require "rails_helper"

RSpec.describe SurveyFormSeeder do
  it "creates the three survey template forms with their roles" do
    expect { described_class.call }.to change(Form, :count).by(3)

    expect(Form.find_by(name: "Day 1 Survey").role).to eq("day_1_survey")
    expect(Form.find_by(name: "Day 2 Survey").role).to eq("day_2_survey")
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
      "Day 1 Survey", "Day 2 Survey", "Post-Training Recipients Survey"
    )
  end
end
