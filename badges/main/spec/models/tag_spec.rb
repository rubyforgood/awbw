RSpec.describe Tag do
	describe ".bg_class_for" do
		it "returns the correct Tailwind bg class for every defined taggable color" do
			Tag::TAGGABLE_COLORS.each do |key, color|
				expect(Tag.bg_class_for(key)).to eq("bg-#{color}-50")
			end
		end

		it "falls back safely for unknown keys" do
			expect(Tag.bg_class_for(:unknown)).to eq("bg-gray-50")
		end

		it "supports intensity overrides" do
			expect(Tag.bg_class_for(:events, intensity: 100)).to eq("bg-blue-100")
		end

		it "defines a color for every taggable model" do
			expect(Tag::TAGGABLE_COLORS.keys)
				.to include(*Tag::TAGGABLE_MODELS.keys)
		end
	end
end
