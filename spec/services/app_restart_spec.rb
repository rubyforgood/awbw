require "rails_helper"

RSpec.describe AppRestart do
  before { allow(Process).to receive(:kill) }

  it "is not available on a developer machine or in tests" do
    expect(described_class.available?).to be(false)
  end

  it "does nothing where it isn't available" do
    expect(described_class.call).to be_nil
    expect(Process).not_to have_received(:kill)
  end

  it "asks puma to shut down so the host starts a fresh container" do
    allow(described_class).to receive(:available?).and_return(true)
    stub_const("AppRestart::DELAY", 0)

    described_class.call.join

    expect(Process).to have_received(:kill).with("TERM", Process.pid)
  end
end
