require "rails_helper"

RSpec.describe "seed: Day 1 training evaluation" do
  let(:seed) { Rails.root.join("db/seeds/forms/day_1_training_evaluation.rb") }
  let(:form) { Form.standalone.find_by!(name: "Day 1 AWBW Facilitator Training Evaluation") }

  def run_seed = expect { load seed }.to output.to_stdout

  it "builds the SurveyMonkey questions in order, all optional" do
    run_seed

    fields = form.form_fields.reorder(:position)
    expect(form.role).to eq("general")
    expect(fields.count).to eq(26)
    expect(fields.map(&:answer_type).tally).to include("single_select_radio" => 14, "file_upload" => 1, "multi_select_checkbox" => 1)
    expect(fields.none?(&:required?)).to be(true)
    expect(fields.second.name).to eq("Name")
    expect(fields.last.answer_options.map(&:name)).to include("My first and last name", "City I'm located in")
  end

  it "keeps the clarity bullet lists in the subtitle and offers a specify box" do
    run_seed

    part_one = form.form_fields.find_by!(position: 4)
    expect(part_one.subtitle).to include("<strong>Listening is Art</strong>")
    expect(part_one.specify_option_labels).to eq([ "Other" ])
  end

  it "is idempotent while the form has no submissions" do
    run_seed
    run_seed

    expect(Form.where(name: form.name).count).to eq(1)
    expect(form.form_fields.count).to eq(26)
  end

  it "leaves a form with submissions untouched" do
    run_seed
    create(:form_submission, form:)
    form.form_fields.first.update!(name: "Edited by staff")

    expect { load seed }.to output(/already has 1 submission/).to_stdout
    expect(form.form_fields.reorder(:position).first.name).to eq("Edited by staff")
  end

  it "names the photo contact when one is given" do
    ENV["PHOTO_CONTACT"] = "the training lead at training@example.org"
    run_seed

    expect(form.form_fields.find_by!(answer_type: :file_upload).name).to end_with("email them to the training lead at training@example.org.")
  ensure
    ENV.delete("PHOTO_CONTACT")
  end

  it "falls back to a generic photo contact" do
    run_seed

    expect(form.form_fields.find_by!(answer_type: :file_upload).name).to end_with("email them to the AWBW training team.")
  end
end
