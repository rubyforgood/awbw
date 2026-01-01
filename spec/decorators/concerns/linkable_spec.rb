require "rails_helper"
require "ostruct"

RSpec.describe LinkableTestDecorator, type: :decorator do
  let(:object) { OpenStruct.new(id: 123, external_url_value: url) }
  let(:decorator) { described_class.new(object) }

  before do
    allow(decorator.h)
      .to receive(:polymorphic_path)
            .with(object)
            .and_return("/fake/123")
  end

  describe "#external_link?" do
    subject { decorator.external_link? }

    context "when external_url is valid" do
      let(:url) { "example.com" }
      it { is_expected.to eq true }
    end

    context "when external_url is blank" do
      let(:url) { "" }
      it { is_expected.to eq false }
    end

    context "when external_url is invalid" do
      let(:url) { "not a url" }
      it { is_expected.to eq false }
    end

    context "when external_url has a non-http scheme" do
      let(:url) { "ftp://example.com" }
      it { is_expected.to eq false }
    end
  end

  describe "#link_target" do
    subject { decorator.link_target }

    context "when external_url is present and valid" do
      let(:url) { "example.com" }
      it { is_expected.to eq "https://example.com" }
    end

    context "when external_url has http scheme" do
      let(:url) { "http://example.com" }
      it { is_expected.to eq "http://example.com" }
    end

    context "when external_url has https scheme" do
      let(:url) { "https://example.com" }
      it { is_expected.to eq "https://example.com" }
    end

    context "when external_url is invalid" do
      let(:url) { "not a url" }
      it { is_expected.to eq "/fake/123" }
    end

    context "when external_url is blank" do
      let(:url) { "" }
      it { is_expected.to eq "/fake/123" }
    end
  end

  describe "URL normalization (private behavior)" do
    subject { decorator.send(:valid_external_url?, url) }

    context "with fully qualified http URL" do
      let(:url) { "http://example.com" }
      it { is_expected.to eq true }
    end

    context "with fully qualified https URL" do
      let(:url) { "https://example.com" }
      it { is_expected.to eq true }
    end

    context "with missing scheme" do
      let(:url) { "example.com" }
      it { is_expected.to eq true }
    end

    context "with invalid URL" do
      let(:url) { "not a url" }
      it { is_expected.to eq false }
    end

    context "with nil" do
      let(:url) { nil }
      it { is_expected.to eq false }
    end
  end
end
