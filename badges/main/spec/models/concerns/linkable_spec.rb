require "rails_helper"

RSpec.describe Linkable, type: :module do
	let(:model) { LinkableTestModel.new(id: 123, external_url_value: url) }

	describe "#valid_external_url?" do
		subject { model.send(:valid_external_url?, url) }

		context "with a fully qualified http URL" do
			let(:url) { "http://example.com" }
			it { is_expected.to eq true }
		end

		context "with a fully qualified https URL" do
			let(:url) { "https://example.com" }
			it { is_expected.to eq true }
		end

		context "with a missing scheme" do
			let(:url) { "example.com" }
			it { is_expected.to eq true }  # normalized to https://example.com
		end

		context "with an invalid URL" do
			let(:url) { "not a url" }
			it { is_expected.to eq false }
		end

		context "with a non-http scheme" do
			let(:url) { "ftp://example.com" }
			it { is_expected.to eq false }
		end

		context "with nil" do
			let(:url) { nil }
			it { is_expected.to eq false }
		end
	end

	describe "#external_link?" do
		subject { model.external_link? }

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
	end

	describe "#normalized_url" do
		subject { model.send(:normalized_url, url) }

		context "when URL already has http" do
			let(:url) { "http://example.com" }
			it { is_expected.to eq "http://example.com" }
		end

		context "when URL already has https" do
			let(:url) { "https://example.com" }
			it { is_expected.to eq "https://example.com" }
		end

		context "when URL is missing scheme" do
			let(:url) { "example.com" }
			it { is_expected.to eq "https://example.com" }
		end

		context "when blank" do
			let(:url) { "" }
			it { is_expected.to eq "" }
		end
	end

	describe "#link_target" do
		subject { model.link_target }

		context "when external_url is present and valid" do
			let(:url) { "example.com" }
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
end
