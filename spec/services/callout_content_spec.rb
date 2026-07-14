require "rails_helper"

RSpec.describe CalloutContent do
  describe ".segments" do
    it "returns a single :html segment when there are no toggles" do
      segments = described_class.segments("<p>Bring scissors</p><ul><li>Paper</li></ul>")

      expect(segments.map(&:type)).to eq([ :html ])
      expect(segments.first.html).to eq("<p>Bring scissors</p><ul><li>Paper</li></ul>")
    end

    it "returns an empty list for blank content" do
      expect(described_class.segments(nil)).to be_empty
      expect(described_class.segments("")).to be_empty
    end

    it "splits a <toggle> out of the surrounding content, preserving order" do
      html = "<p>Intro</p><toggle title=\"Workshop 1\"><ul><li>Glue</li></ul></toggle><p>After</p>"
      segments = described_class.segments(html)

      expect(segments.map(&:type)).to eq([ :html, :toggle, :html ])
      expect(segments[0].html).to eq("<p>Intro</p>")
      expect(segments[1].summary).to eq("Workshop 1")
      expect(segments[1].html).to eq("<ul><li>Glue</li></ul>")
      expect(segments[2].html).to eq("<p>After</p>")
    end

    it "reads the summary from a leading <summary> and drops it from the body" do
      segments = described_class.segments("<toggle><summary>Workshop 2</summary><p>Markers</p></toggle>")

      expect(segments.first.type).to eq(:toggle)
      expect(segments.first.summary).to eq("Workshop 2")
      expect(segments.first.html).to eq("<p>Markers</p>")
    end

    it "keeps multiple toggles as separate segments" do
      html = "<toggle title=\"A\"><p>one</p></toggle><toggle title=\"B\"><p>two</p></toggle>"
      segments = described_class.segments(html)

      expect(segments.map(&:type)).to eq([ :toggle, :toggle ])
      expect(segments.map(&:summary)).to eq([ "A", "B" ])
    end

    it "falls back to a generic summary for a toggle with no title or <summary>" do
      segments = described_class.segments("<toggle><p>Body</p></toggle>")

      expect(segments.first.summary).to eq("Details")
    end

    it "does not emit a whitespace-only segment between toggles" do
      html = "<toggle title=\"A\"><p>one</p></toggle>\n\n<toggle title=\"B\"><p>two</p></toggle>"
      segments = described_class.segments(html)

      expect(segments.map(&:type)).to eq([ :toggle, :toggle ])
    end
  end
end
