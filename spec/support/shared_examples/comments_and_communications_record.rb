RSpec.shared_examples "a comments and communications record" do
  it "includes Communicable" do
    expect(described_class.include?(Communicable)).to be(true)
  end

  it "exposes comments and communications_scope" do
    record = described_class.new
    expect(record).to respond_to(:comments)
    expect(record).to respond_to(:communications_scope)
  end
end
