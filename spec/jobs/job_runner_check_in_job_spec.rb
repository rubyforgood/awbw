require "rails_helper"

RSpec.describe JobRunnerCheckInJob, type: :job do
  let(:check_in_id) { nil }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("HONEYBADGER_JOB_RUNNER_CHECK_IN_ID").and_return(check_in_id)
    allow(Honeybadger).to receive(:check_in)
  end

  context "with a check-in configured" do
    let(:check_in_id) { "abc123" }

    it "checks in with Honeybadger" do
      described_class.perform_now

      expect(Honeybadger).to have_received(:check_in).with("abc123")
    end
  end

  context "without a check-in configured" do
    it "does nothing" do
      described_class.perform_now

      expect(Honeybadger).not_to have_received(:check_in)
    end
  end

  it "is scheduled in production" do
    recurring = YAML.load(ERB.new(Rails.root.join("config/recurring.yml").read).result)
    task = recurring.dig("production", "job_runner_check_in")

    expect(task["class"]).to eq(described_class.name)
  end
end
