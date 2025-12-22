# spec/lib/domain_theme_spec.rb
require "rails_helper"

RSpec.describe DomainTheme do
	describe ".bg_class_for" do
		it "returns the correct Tailwind bg class for every defined color" do
			DomainTheme::COLORS.each do |key, color|
				expect(DomainTheme.bg_class_for(key))
					.to eq("bg-#{color}-50")
			end
		end

		it "falls back safely for unknown keys" do
			expect(DomainTheme.bg_class_for(:unknown))
				.to eq("bg-gray-50")
		end

		it "supports intensity overrides" do
			expect(DomainTheme.bg_class_for(:events, intensity: 100))
				.to eq("bg-blue-100")
		end

		it "supports hover classes for 100's" do
			expect(DomainTheme.bg_class_for(:stories, intensity: 200, hover: true))
				.to eq("hover:bg-rose-300")
		end

		it "supports hover classes for 50" do
			expect(DomainTheme.bg_class_for(:stories, intensity: 50, hover: true))
				.to eq("hover:bg-rose-100")
		end

		it "defines a color for every taggable dashboard type" do
			# Tag::TAGGABLE_META keys: workshops, resources, community_news, stories, events, facilitators, projects, quotes
			expect(DomainTheme::COLORS.keys)
				.to include(*Tag::TAGGABLE_META.keys)
		end
	end

	describe ".color_for" do
		it "returns configured color symbols" do
			expect(DomainTheme.color_for(:workshops)).to eq(:indigo)
		end

		it "symbolizes string keys" do
			expect(DomainTheme.color_for("projects")).to eq(:emerald)
		end

		it "returns gray for unknown keys" do
			expect(DomainTheme.color_for(:missing)).to eq(:gray)
		end
	end
end
