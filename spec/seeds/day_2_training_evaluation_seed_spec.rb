require "rails_helper"

RSpec.describe "seed: Day 2 training evaluation" do
  let(:seed) { Rails.root.join("db/seeds/forms/day_2_training_evaluation.rb") }
  let(:form) { Form.standalone.find_by!(role: "day_2_survey") }

  def run_seed = expect { load seed }.to output.to_stdout

  before { create(:user, :admin) }

  it "builds the SurveyMonkey questions in order, all optional" do
    run_seed

    fields = form.form_fields.reorder(:position)
    expect(form.role).to eq("day_2_survey")
    expect(fields.count).to eq(23)
    expect(fields.map(&:answer_type).tally).to include("single_select_radio" => 10, "file_upload" => 1, "multi_select_checkbox" => 1)
    expect(fields.none?(&:required?)).to be(true)
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

  it "fans each growth question out over the day's workshops, in order" do
    run_seed

    growth = form.form_fields.where(name: [ FormBuilderService::GROWTH_PERSONAL_PROMPT, FormBuilderService::GROWTH_PROFESSIONAL_PROMPT ])
    expect(growth.count).to eq(2)
    expect(growth.map { |field| field.fanned_resources.map(&:title) }).to all(eq(SurveyFormSeeder::DAY_2_WORKSHOPS))
  end

  it "reuses an existing workshop resource and creates the missing ones unpublished" do
    existing = create(:resource, title: SurveyFormSeeder::DAY_2_WORKSHOPS.first)

    expect { run_seed }.to change(Resource, :count).by(SurveyFormSeeder::DAY_2_WORKSHOPS.size - 1)
    expect(form.form_fields.find_by!(name: FormBuilderService::GROWTH_PERSONAL_PROMPT).fanned_resources.first).to eq(existing)
    expect(Resource.where(title: SurveyFormSeeder::DAY_2_WORKSHOPS).where.not(id: existing.id)).to all(have_attributes(published: false))
  end

  it "builds the form the Feedback surveys callout delivers" do
    run_seed

    expect(form.name).to eq("Day 2 Survey")
  end

  it "rebuilds the seeded template in place, even after staff renamed it" do
    SurveyFormSeeder.call
    template = Form.find_by!(role: "day_2_survey")
    template.update!(name: "Renamed by staff")

    expect { run_seed }.not_to change(Form, :count)
    expect(template.form_fields.count).to eq(23)
  end

  it "is idempotent while the form has no submissions" do
    run_seed
    run_seed

    expect(Form.where(name: form.name).count).to eq(1)
    expect(form.form_fields.count).to eq(23)
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
