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
        .to eq("hover:bg-fuchsia-300")
    end

    it "supports hover classes for 50" do
      expect(DomainTheme.bg_class_for(:stories, intensity: 50, hover: true))
        .to eq("hover:bg-fuchsia-100")
    end

    it "defines a color for every taggable home type" do
      # Tag::TAGGABLE_META keys: workshops, resources, community_news, stories, events, people, organizations, quotes
      expect(DomainTheme::COLORS.keys)
        .to include(*Tag::TAGGABLE_META.keys)
    end
  end

  describe ".color_for" do
    it "returns configured color symbols" do
      expect(DomainTheme.color_for(:workshops)).to eq(:indigo)
    end

    it "symbolizes string keys" do
      expect(DomainTheme.color_for("organizations")).to eq(:emerald)
    end

    it "returns gray for unknown keys" do
      expect(DomainTheme.color_for(:missing)).to eq(:gray)
    end
  end

  describe ".swatch" do
    it "builds the full set of role classes from one base colour" do
      expect(DomainTheme.swatch(:amber)).to eq(
        icon: "text-amber-500",
        border: "border-amber-300",
        bg: "bg-amber-50",
        hover: "hover:bg-amber-100",
        title: "text-amber-900",
        subtitle: "text-amber-700"
      )
    end

    it "accepts a string colour" do
      expect(DomainTheme.swatch("blue")).to eq(DomainTheme.swatch(:blue))
    end
  end

  describe ".swatch_for" do
    it "resolves a domain key to its colour swatch" do
      expect(DomainTheme.swatch_for(:scholarships))
        .to eq(DomainTheme.swatch(DomainTheme.color_for(:scholarships)))
    end

    it "falls back to gray for unknown keys" do
      expect(DomainTheme.swatch_for(:missing)).to eq(DomainTheme.swatch(:gray))
    end
  end

  describe ".swatches" do
    it "returns every pickable colour keyed by name" do
      expect(DomainTheme.swatches.keys).to eq(DomainTheme::SWATCH_COLORS)
      expect(DomainTheme.swatches[:amber]).to eq(DomainTheme.swatch(:amber))
    end
  end
end
