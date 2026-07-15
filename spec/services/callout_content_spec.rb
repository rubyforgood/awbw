require "rails_helper"

RSpec.describe CalloutContent do
  describe ".segments" do
    it "returns a single :html segment when there are no disclosures" do
      segments = described_class.segments("<p>Bring scissors</p><ul><li>Paper</li></ul>")

      expect(segments.map(&:type)).to eq([ :html ])
      expect(segments.first.html).to eq("<p>Bring scissors</p><ul><li>Paper</li></ul>")
    end

    it "returns an empty list for blank content" do
      expect(described_class.segments(nil)).to be_empty
      expect(described_class.segments("")).to be_empty
    end

    it "splits a <details> out of the surrounding content, preserving order" do
      html = "<p>Intro</p><details><summary>Workshop 1</summary><ul><li>Glue</li></ul></details><p>After</p>"
      segments = described_class.segments(html)

      expect(segments.map(&:type)).to eq([ :html, :toggle, :html ])
      expect(segments[0].html).to eq("<p>Intro</p>")
      expect(segments[1].summary).to eq("Workshop 1")
      expect(segments[1].html).to eq("<ul><li>Glue</li></ul>")
      expect(segments[1].open).to be(false)
      expect(segments[2].html).to eq("<p>After</p>")
    end

    it "marks a <details open> segment as expanded" do
      segments = described_class.segments("<details open><summary>W</summary><p>x</p></details>")

      expect(segments.first.open).to be(true)
    end

    it "accepts <toggle> as an alias and a title attribute as the summary" do
      segments = described_class.segments("<toggle title=\"Workshop 2\"><p>Markers</p></toggle>")

      expect(segments.first.type).to eq(:toggle)
      expect(segments.first.summary).to eq("Workshop 2")
      expect(segments.first.html).to eq("<p>Markers</p>")
    end

    it "keeps multiple disclosures as separate segments" do
      html = "<details><summary>A</summary><p>one</p></details><details><summary>B</summary><p>two</p></details>"
      segments = described_class.segments(html)

      expect(segments.map(&:type)).to eq([ :toggle, :toggle ])
      expect(segments.map(&:summary)).to eq([ "A", "B" ])
    end

    it "falls back to a generic summary for a disclosure with no summary or title" do
      segments = described_class.segments("<details><p>Body</p></details>")

      expect(segments.first.summary).to eq("Details")
    end

    it "does not emit a whitespace-only segment between disclosures" do
      html = "<details><summary>A</summary><p>one</p></details>\n\n<details><summary>B</summary><p>two</p></details>"
      segments = described_class.segments(html)

      expect(segments.map(&:type)).to eq([ :toggle, :toggle ])
    end
  end
end
