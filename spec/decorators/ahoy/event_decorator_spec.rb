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
          { label: "Results found", value: "3", depth: 0 }
        ]
      )
    end

    it "labels both result_count and the legacy page_result_count as Results found" do
      current = decorate("result_count" => 8)
      legacy = decorate("page_result_count" => 21)
      expect(current.detail_rows).to eq([ { label: "Results found", value: "8", depth: 0 } ])
      expect(legacy.detail_rows).to eq([ { label: "Results found", value: "21", depth: 0 } ])
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

    it "collapses an array of named entities onto one line" do
      event = decorate(
        "filters" => {
          "sectors" => [ { "id" => 9, "name" => "Education" }, { "id" => 2, "name" => "Youth" } ],
          "categories" => [ { "id" => 10, "name" => "Journaling", "type" => "ArtType" } ]
        }
      )
      expect(event.detail_rows).to eq(
        [
          { label: "Filters", value: nil, depth: 0 },
          { label: "Sectors", value: "Education, Youth", depth: 1 },
          { label: "Categories", value: "Journaling (Art type)", depth: 1 }
        ]
      )
    end

    it "excludes the changes diff (rendered separately)" do
      event = decorate("changes" => { "title" => { "before" => "A", "after" => "B" } })
      expect(event.detail_rows).to eq([])
    end
  end

  describe "record references" do
    it "links an association change to the record's show page" do
      workshop = create(:workshop)
      event = decorate(
        "association_changes" => {
          "workshops" => [ { "action" => "added", "id" => workshop.id, "type" => "Workshop" } ]
        }
      )
      rows = event.detail_rows

      header = rows.find { |r| r[:label] == "Association changes" }
      expect(header[:value]).to be_nil

      link_row = rows.find { |r| r[:link] }
      expect(link_row[:action]).to eq("added")
      expect(link_row[:link][:text]).to eq(workshop.title)
      expect(link_row[:link][:path]).to eq(Rails.application.routes.url_helpers.workshop_path(workshop))
    end

    it "falls back to type + id when the record is gone" do
      event = decorate(
        "associated_records" => [ { "record_type" => "Workshop", "record_id" => 0 } ]
      )
      link_row = event.detail_rows.find { |r| r[:link] }
      expect(link_row[:link][:text]).to eq("Workshop #0")
      expect(link_row[:link][:path]).to be_nil
    end
  end
end
