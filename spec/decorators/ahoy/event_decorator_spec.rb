require "rails_helper"

RSpec.describe Ahoy::EventDecorator do
  def decorate(properties)
    create(:ahoy_event, properties: properties).reload.decorate
  end

  describe "#extra_properties" do
    it "drops the keys already shown in their own columns" do
      event = decorate(
        "resource_type" => "Workshop",
        "resource_id" => 1,
        "resource_title" => "Test",
        "source" => "import"
      )
      expect(event.extra_properties).to eq("source" => "import")
    end

    it "is empty when only the redundant keys are present" do
      event = decorate("resource_type" => "Workshop", "resource_id" => 1, "resource_title" => "Test")
      expect(event.extra_details?).to be(false)
    end
  end

  describe "#changes?" do
    it "is true for an update event with a changes diff" do
      event = decorate("changes" => { "title" => { "before" => "Old", "after" => "New" } })
      expect(event.changes?).to be(true)
    end

    it "is false when there is no changes diff" do
      event = decorate("resource_title" => "Test")
      expect(event.changes?).to be(false)
    end
  end

  describe "#changes_summary" do
    it "humanizes the field and formats before/after values" do
      event = decorate(
        "changes" => {
          "display_name" => { "before" => "Old", "after" => "New" },
          "active" => { "before" => false, "after" => true },
          "note" => { "before" => nil, "after" => "" }
        }
      )

      expect(event.changes_summary).to match_array(
        [
          { field: "Display name", before: "Old", after: "New" },
          { field: "Active", before: "No", after: "Yes" },
          { field: "Note", before: "(empty)", after: "(empty)" }
        ]
      )
    end

    it "is empty when the event has no changes" do
      event = decorate("resource_title" => "Test")
      expect(event.changes_summary).to eq([])
    end
  end

  describe "#detail_rows" do
    it "flattens scalar extras into humanized rows" do
      event = decorate("resource_title" => "Test", "source" => "import", "result_count" => 3)
      expect(event.detail_rows).to match_array(
        [
          { label: "Source", value: "import", depth: 0 },
          { label: "Result count", value: "3", depth: 0 }
        ]
      )
    end

    it "indents a nested hash under its label" do
      event = decorate("keywords" => { "full_text" => "watercolor" })
      expect(event.detail_rows).to eq(
        [
          { label: "Keywords", value: nil, depth: 0 },
          { label: "Full text", value: "watercolor", depth: 1 }
        ]
      )
    end

    it "joins an array of scalars into one row" do
      event = decorate("sectors" => %w[Veterans Youth])
      expect(event.detail_rows).to eq([ { label: "Sectors", value: "Veterans, Youth", depth: 0 } ])
    end

    it "excludes the changes diff (rendered separately)" do
      event = decorate("changes" => { "title" => { "before" => "A", "after" => "B" } })
      expect(event.detail_rows).to eq([])
    end
  end
end
