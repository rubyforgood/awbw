# frozen_string_literal: true

require "rails_helper"

RSpec.describe DisplayImagePresenter do
  let(:view_context) { ApplicationController.new.view_context }

  describe ".call" do
    context "when file is nil" do
      it "returns :none display_type" do
        result = described_class.call(file: nil, view_context: view_context)
        expect(result.display_type).to eq(:none)
      end
    end

    context "when file is a Symbol (icon)" do
      it "returns :icon display_type" do
        result = described_class.call(file: :scholarship, view_context: view_context)
        expect(result.display_type).to eq(:icon)
      end

      it "does not set a renderable" do
        result = described_class.call(file: :scholarship, view_context: view_context)
        expect(result.renderable).to be_nil
      end

      it "does not set a link_href" do
        result = described_class.call(file: :scholarship, view_context: view_context)
        expect(result.link_href).to be_nil
      end
    end

    context "when file is a String (fallback)" do
      it "returns :fallback display_type" do
        result = described_class.call(file: "workshop_default.jpg", view_context: view_context)
        expect(result.display_type).to eq(:fallback)
      end

      it "sets the string as renderable" do
        result = described_class.call(file: "workshop_default.jpg", view_context: view_context)
        expect(result.renderable).to eq("workshop_default.jpg")
      end

      it "builds fallback alt text" do
        result = described_class.call(file: "workshop_default.jpg", idx: 2, item_type: "Workshop", view_context: view_context)
        expect(result.alt_text).to eq("Workshop fallback image 3")
      end
    end

    context "when file is an Active Storage attachment (image)" do
      let(:asset) { create(:primary_asset, :with_file) }
      let(:file) { asset.file }

      it "returns :active_storage display_type" do
        result = described_class.call(file: file, view_context: view_context)
        expect(result.display_type).to eq(:active_storage)
      end

      it "uses variant(:thumbnail) for gallery variant" do
        result = described_class.call(file: file, variant: :gallery, view_context: view_context)
        expect(result.renderable).to be_a(ActiveStorage::VariantWithRecord)
      end

      it "uses the original file for hero variant" do
        result = described_class.call(file: file, variant: :hero, view_context: view_context)
        expect(result.renderable).to eq(file)
      end

      it "uses variant(:thumbnail) for index variant" do
        result = described_class.call(file: file, variant: :index, view_context: view_context)
        expect(result.renderable).to be_a(ActiveStorage::VariantWithRecord)
      end

      it "builds alt text with filename" do
        result = described_class.call(file: file, idx: 0, item_type: "Main", view_context: view_context)
        expect(result.alt_text).to include("missing.png")
        expect(result.alt_text).to include("Main image 1")
      end
    end

    context "CSS classes" do
      it "builds hero image classes" do
        result = described_class.call(file: "test.jpg", variant: :hero, view_context: view_context)
        expect(result.image_classes).to include("hero-size")
        expect(result.image_classes).to include("w-full")
      end

      it "builds gallery image classes with dimensions" do
        result = described_class.call(file: "test.jpg", variant: :gallery, width: "32", height: "32", view_context: view_context)
        expect(result.image_classes).to include("gallery-size")
        expect(result.image_classes).to include("w-32")
        expect(result.image_classes).to include("h-32")
      end

      it "builds index wrapper classes with dimensions" do
        result = described_class.call(file: "test.jpg", variant: :index, width: "24", height: "24", view_context: view_context)
        expect(result.wrapper_classes).to include("index-size")
        expect(result.wrapper_classes).to include("w-24")
        expect(result.wrapper_classes).to include("h-24")
      end

      it "uses w-auto for unknown widths" do
        result = described_class.call(file: "test.jpg", variant: :gallery, width: "99", view_context: view_context)
        expect(result.image_classes).to include("w-auto")
      end

      it "includes extra_image_classes" do
        result = described_class.call(file: "test.jpg", variant: :hero, extra_image_classes: "custom-class", view_context: view_context)
        expect(result.image_classes).to include("custom-class")
      end
    end

    context "link options" do
      it "builds link_to_object options with turbo data" do
        resource = create(:workshop)
        allow(view_context).to receive(:polymorphic_path).with(resource).and_return("/workshops/#{resource.id}")
        result = described_class.call(file: "missing.png", link_to_object: true, resource: resource, view_context: view_context)
        expect(result.link_options).to include(
          class: "display-image-link",
          data: { turbo_frame: "_top", turbo_prefetch: false }
        )
        expect(result.link_href).to eq("/workshops/#{resource.id}")
      end

      it "builds external link options" do
        result = described_class.call(file: "missing.png", link_to_object: false, link: true, view_context: view_context)
        expect(result.link_options).to include(
          class: "display-image-link",
          target: "_blank",
          rel: "noopener noreferrer"
        )
      end

      it "does not set link_href when link is false" do
        result = described_class.call(file: "missing.png", link: false, view_context: view_context)
        expect(result.link_href).to be_nil
      end
    end

    context "item parameter" do
      let(:asset) { create(:primary_asset, :with_file) }

      it "extracts file from item" do
        result = described_class.call(item: asset, view_context: view_context)
        expect(result.display_type).to eq(:active_storage)
      end
    end
  end
end
