require "rails_helper"

RSpec.describe Analytics::LifecycleBuffer do
  # The buffer is a thread-local shared across the worker, so an event another
  # test left unflushed would otherwise bleed into these assertions. Start and
  # end each example from a clean buffer.
  before do
    described_class.store.clear
    Current.form_submission_id = nil
  end

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

  it "flushes to a tracker directly, for work that runs outside a request" do
    described_class.push(name: "create.person", properties: { resource_type: "Person" })

    tracked = []
    described_class.flush_to(build_controller(tracked).ahoy)

    expect(tracked).to eq([ [ "create.person", { resource_type: "Person" } ] ])
    expect(described_class.store).to be_empty
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

  describe ".tagging" do
    it "adds the properties to only the events buffered inside the block, and returns its value" do
      described_class.push(name: "update.person", properties: { resource_type: "Person" })

      result = described_class.tagging(profile_change_request_id: 9) do
        described_class.push(name: "update.affiliation", properties: { resource_type: "Affiliation" })
        described_class.push(name: "create.address", properties: nil)
        :applied
      end

      tracked = []
      described_class.flush(build_controller(tracked))

      expect(result).to eq(:applied)
      expect(tracked).to contain_exactly(
        [ "update.person", { resource_type: "Person" } ],
        [ "update.affiliation", hash_including(profile_change_request_id: 9) ],
        [ "create.address", { profile_change_request_id: 9 } ]
      )
    end

    it "keeps a value an event already carries" do
      described_class.tagging(profile_change_request_id: 9) do
        described_class.push(name: "update.affiliation", properties: { profile_change_request_id: 3 })
      end

      tracked = []
      described_class.flush(build_controller(tracked))

      expect(tracked.first.last[:profile_change_request_id]).to eq(3)
    end
  end
end
