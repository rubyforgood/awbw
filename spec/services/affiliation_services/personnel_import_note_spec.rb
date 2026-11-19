require "rails_helper"

RSpec.describe AffiliationServices::PersonnelImportNote do
  it "finds the end-date source an import comment names" do
    body = "FileMaker Personnel PS1: role Leader, status Inactive. Ends 2014-12-31, from #{described_class::END_SOURCES[:stand_in]}."
    expect(described_class.end_source_in(body)).to eq(:stand_in)
  end

  it "finds nothing in a comment without an end-date phrase" do
    expect(described_class.end_source_in("FileMaker Personnel PS1: status Active.")).to be_nil
    expect(described_class.end_source_in(nil)).to be_nil
  end

  it "labels every end-date source" do
    expect(described_class::END_SOURCE_LABELS.keys).to eq(described_class::END_SOURCES.keys)
  end
end
