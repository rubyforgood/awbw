# spec/models/concerns/linkable_spec.rb
require "rails_helper"

RSpec.describe Linkable do
	let(:model_class) do
		Class.new(ApplicationRecord) do
			self.table_name = "stories"
			include Linkable
		end
	end

	let(:record) { model_class.new(id: 123, website_url: website_url) }

	before do
		allow(Rails.application.routes.url_helpers)
			.to receive(:polymorphic_path)
						.and_return("/stories/123")
	end

	context "when website_url is present" do
		let(:website_url) { "https://example.com" }

		it "returns the website_url" do
			expect(record.link_target).to eq("https://example.com")
		end
	end

	context "when website_url is blank" do
		let(:website_url) { nil }

		it "falls back to the polymorphic path" do
			expect(record.link_target).to eq("/stories/123")
		end
	end
end
