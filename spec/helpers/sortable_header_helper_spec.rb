require "rails_helper"

RSpec.describe SortableHeaderHelper, type: :helper do
  describe "#sort_icon_class" do
    it "returns the neutral arrow for an inactive column" do
      assign(:sort, "title")
      assign(:sort_direction, "asc")
      expect(helper.sort_icon_class("author")).to eq("fa-sort")
    end

    it "returns the up arrow for the active ascending column" do
      assign(:sort, "title")
      assign(:sort_direction, "asc")
      expect(helper.sort_icon_class("title")).to eq("fa-arrow-up")
    end

    it "returns the down arrow for the active descending column" do
      assign(:sort, "title")
      assign(:sort_direction, "desc")
      expect(helper.sort_icon_class("title")).to eq("fa-arrow-down")
    end
  end

  describe "#sort_header_link" do
    let(:link) do
      helper.sort_header_link(frame: "stories_results",
                              path: ->(p) { "/stories?#{p.to_query}" },
                              base: { query: "art" })
    end

    it "toggles an active descending column to ascending" do
      assign(:sort, "title")
      assign(:sort_direction, "desc")
      html = link.call("title", "Title")
      expect(html).to include("direction=asc")
      expect(html).to include("sort=title")
      expect(html).to include("query=art")
      expect(html).to include('data-turbo-frame="stories_results"')
    end

    it "defaults a fresh column to descending" do
      assign(:sort, "created_at")
      assign(:sort_direction, "asc")
      html = link.call("title", "Title")
      expect(html).to include("direction=desc")
    end
  end
end
