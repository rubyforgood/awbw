require "rails_helper"

RSpec.describe Analytics::LifecycleBuffer do
  after do
    described_class.store.clear
    Current.form_submission_id = nil
  end

  def build_controller(tracked)
    ahoy = instance_double(Ahoy::Tracker)
    allow(ahoy).to receive(:track) { |name, props| tracked << [ name, props ] }
    double("controller", ahoy: ahoy)
  end

  it "stamps the current form submission id onto every flushed event's properties" do
    Current.form_submission_id = 42
    described_class.push(name: "update.organization", properties: { resource_type: "Organization" })
    described_class.push(name: "create.affiliation", properties: { resource_type: "Affiliation" })

    tracked = []
    described_class.flush(build_controller(tracked))

    expect(tracked).to contain_exactly(
      [ "update.organization", hash_including(form_submission_id: 42) ],
      [ "create.affiliation", hash_including(form_submission_id: 42) ]
    )
  end

  it "leaves properties untouched when no form submission id is set" do
    described_class.push(name: "update.person", properties: { resource_type: "Person" })

    tracked = []
    described_class.flush(build_controller(tracked))

    expect(tracked.first.last).not_to have_key(:form_submission_id)
  end

  it "does not overwrite a form submission id already on the payload" do
    Current.form_submission_id = 42
    described_class.push(name: "update.organization", properties: { form_submission_id: 7 })

    tracked = []
    described_class.flush(build_controller(tracked))

    expect(tracked.first.last[:form_submission_id]).to eq(7)
  end
end
