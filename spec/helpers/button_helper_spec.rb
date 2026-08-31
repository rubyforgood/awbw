require "rails_helper"

RSpec.describe ButtonHelper, type: :helper do
  describe "#button_classes" do
    it "combines the base, default size, and the requested variant" do
      result = helper.button_classes(:primary)

      expect(result).to include("inline-flex", "rounded-lg", "shadow-sm")
      expect(result).to include("px-4", "py-2", "text-sm")
      expect(result).to include("bg-primary", "hover:text-primary")
    end

    it "defaults to the primary variant" do
      expect(helper.button_classes).to eq(helper.button_classes(:primary))
    end

    it "swaps in the compact size" do
      result = helper.button_classes(:secondary_outline, size: :sm)

      expect(result).to include("px-3", "py-1", "text-xs")
      expect(result).not_to include("px-4", "py-2", "text-sm")
    end

    it "omits size utilities when size is nil so a call site can supply its own" do
      result = helper.button_classes(:success, size: nil, extra: "px-10 py-2 text-2xl")

      expect(result).not_to include("px-4", "text-sm")
      expect(result).to include("px-10", "text-2xl")
    end

    it "yields base (and size) with no color when the variant is nil" do
      result = helper.button_classes(nil, extra: "bg-orange-600 text-white")

      expect(result).to include("inline-flex", "rounded-lg", "px-4", "py-2")
      expect(result).to include("bg-orange-600", "text-white")
      expect(result).not_to include("bg-primary", "bg-secondary")
    end

    it "appends extra classes" do
      expect(helper.button_classes(:primary, extra: "whitespace-nowrap")).to include("whitespace-nowrap")
    end

    it "renders the yellow brand variant" do
      result = helper.button_classes(:brand)

      expect(result).to include("bg-brand-yellow-400", "hover:bg-brand-yellow-600", "text-brand-navy-900")
    end

    it "renders the raised yellow brand variant with a darker bottom lip" do
      result = helper.button_classes(:brand_raised)

      expect(result).to include("bg-brand-yellow-400", "text-brand-navy-900", "font-bold")
      expect(result).to include("border-b-4", "border-brand-yellow-600", "hover:border-brand-yellow-700")
    end

    it "defaults to the rounded-lg shape" do
      expect(helper.button_classes(:primary)).to include("rounded-lg")
    end

    it "swaps in the pill shape" do
      result = helper.button_classes(:brand, shape: :pill)

      expect(result).to include("rounded-full")
      expect(result).not_to include("rounded-lg")
    end

    it "omits the radius when shape is nil so a call site can supply its own" do
      result = helper.button_classes(:primary, shape: nil, extra: "rounded-none")

      expect(result).not_to include("rounded-lg")
      expect(result).to include("rounded-none")
    end

    it "raises for an unknown variant so typos fail loudly" do
      expect { helper.button_classes(:nope) }.to raise_error(KeyError)
    end
  end

  describe "#brand_cta_classes" do
    it "renders the gold fill with the raised and pressed edge tokens" do
      result = helper.brand_cta_classes

      expect(result).to include("bg-brand-yellow-400", "text-brand-navy-900")
      expect(result).to include("shadow-brand-cta", "active:shadow-brand-cta-pressed")
    end

    it "takes the edge from the theme token rather than a hard-coded hex" do
      expect(helper.brand_cta_classes).not_to match(/#[0-9a-f]{6}/i)
    end

    it "layers the display face on register buttons only" do
      expect(helper.brand_cta_classes(register: true)).to include("font-display", "uppercase")
      expect(helper.brand_cta_classes).not_to include("font-display")
    end

    it "appends extra classes" do
      expect(helper.brand_cta_classes(extra: "px-10 py-3")).to include("px-10", "py-3")
    end
  end
end
