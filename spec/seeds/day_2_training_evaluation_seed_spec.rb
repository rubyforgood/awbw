require "rails_helper"

RSpec.describe "seed: Day 2 training evaluation" do
  let(:seed) { Rails.root.join("db/seeds/forms/day_2_training_evaluation.rb") }
  let(:form) { Form.standalone.find_by!(name: "Day 2 AWBW Facilitator Training Evaluation") }

  def run_seed = expect { load seed }.to output.to_stdout

  it "builds the SurveyMonkey questions in order, all optional" do
    run_seed

    fields = form.form_fields.reorder(:position)
    expect(form.role).to eq("day_2_survey")
    expect(fields.count).to eq(25)
    expect(fields.map(&:answer_type).tally).to include("single_select_radio" => 12, "file_upload" => 1, "multi_select_checkbox" => 1)
    expect(fields.none?(&:required?)).to be(true)
    expect(fields.map(&:name)).to include("The Claiming Who I Am workshop supported my professional growth.")
    expect(fields.last.answer_options.map(&:name)).to include("My first and last name", "City I'm located in")
  end

  it "keeps the agenda bullet lists in the subtitle and offers a specify box" do
    run_seed

    part_one = form.form_fields.find_by!(position: 4)
    expect(part_one.subtitle).to include("<strong>Intersectionality</strong>")
    expect(part_one.specify_option_labels).to eq([ "Other" ])
  end

  it "asks the warm-up question as yes, no, or other" do
    run_seed

    warm_up = form.form_fields.find { |field| field.name.start_with?("To best prepare") }
    expect(warm_up.answer_options.map(&:name)).to eq([ "Yes", "No", "Other" ])
  end

  it "is idempotent while the form has no submissions" do
    run_seed
    run_seed

    expect(Form.where(name: form.name).count).to eq(1)
    expect(form.form_fields.count).to eq(25)
  end

  it "leaves a form with submissions untouched" do
    run_seed
    create(:form_submission, form:)
    form.form_fields.first.update!(name: "Edited by staff")

    expect { load seed }.to output(/already has 1 submission/).to_stdout
    expect(form.form_fields.reorder(:position).first.name).to eq("Edited by staff")
  end

  it "falls back to a generic photo contact" do
    run_seed

    expect(form.form_fields.find_by!(answer_type: :file_upload).name).to end_with("email them to the AWBW training team.")
  end
end
