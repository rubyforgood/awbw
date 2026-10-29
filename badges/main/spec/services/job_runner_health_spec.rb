require "rails_helper"

RSpec.describe JobRunnerHealth do
  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("SOLID_QUEUE_IN_PUMA").and_return(runs_in_puma)
    allow(described_class).to receive(:last_worker_heartbeat_at).and_return(last_heartbeat_at)
  end

  context "when the job runner runs inside this web process" do
    let(:runs_in_puma) { "true" }

    context "and this container's worker checked in recently" do
      let(:last_heartbeat_at) { 1.minute.ago }

      it { expect(described_class.alive?).to be(true) }
    end

    context "and this container's worker has gone quiet" do
      let(:last_heartbeat_at) { 6.minutes.ago }

      it { expect(described_class.alive?).to be(false) }
    end

    context "and this container has no worker registered" do
      let(:last_heartbeat_at) { nil }

      it { expect(described_class.alive?).to be(false) }
    end
  end

  context "when the job runner does not run inside this web process" do
    let(:runs_in_puma) { nil }
    let(:last_heartbeat_at) { nil }

    it "has nothing to check" do
      expect(described_class.alive?).to be(true)
      expect(described_class).not_to have_received(:last_worker_heartbeat_at)
    end
  end
end
