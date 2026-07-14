require "rails_helper"

RSpec.describe EventDetailsSections do
  describe ".split" do
    it "returns the whole fragment as the lead when there are no <h3> headings" do
      lead, sections = described_class.split("<p>Bring scissors</p><ul><li>Paper</li></ul>")

      expect(lead).to eq("<p>Bring scissors</p><ul><li>Paper</li></ul>")
      expect(sections).to be_empty
    end

    it "splits the content before the first <h3> into the lead" do
      html = "<p>Intro</p><h3>Workshop 1</h3><ul><li>Glue</li></ul>"
      lead, _sections = described_class.split(html)

      expect(lead).to eq("<p>Intro</p>")
    end

    it "creates one section per <h3>, using its text as the heading" do
      html = "<h3>Workshop 1</h3><ul><li>Glue</li></ul><h3>Workshop 2</h3><p>Markers</p>"
      _lead, sections = described_class.split(html)

      expect(sections.map(&:heading)).to eq([ "Workshop 1", "Workshop 2" ])
      expect(sections.first.body_html).to eq("<ul><li>Glue</li></ul>")
      expect(sections.second.body_html).to eq("<p>Markers</p>")
    end

    it "returns a nil lead when the content opens on a heading" do
      lead, sections = described_class.split("<h3>Workshop 1</h3><p>Glue</p>")

      expect(lead).to be_nil
      expect(sections.map(&:heading)).to eq([ "Workshop 1" ])
    end

    it "handles blank input" do
      lead, sections = described_class.split(nil)

      expect(lead).to be_nil
      expect(sections).to be_empty
    end
  end
end
