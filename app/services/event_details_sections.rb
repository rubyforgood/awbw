# Splits an event-details HTML fragment (the "Art supplies & what to bring" copy)
# into a lead block plus one collapsible section per <h3> heading. The details
# page renders each section — e.g. each workshop's optional supplies — as its own
# <details> toggle built in code from the headings, not authored in the rich
# text, so the toggles can never be stripped by the form_label_html sanitizer
# when the event is saved (that allowlist drops <details>/<summary>). Content
# with no <h3> headings comes back as a single lead block and renders unchanged.
class EventDetailsSections
  # One collapsible section: the <h3> text becomes the toggle summary; the nodes
  # up to the next <h3> become its body HTML.
  Section = Data.define(:heading, :body_html)

  def self.split(html)
    new(html).split
  end

  def initialize(html)
    @html = html.to_s
  end

  # Returns [ lead_html, sections ]: `lead_html` is everything before the first
  # <h3> (nil when there's nothing but whitespace, e.g. content opening on a
  # heading); `sections` is the ordered list of Section structs.
  def split
    lead_nodes = []
    sections = []
    current = nil

    fragment.children.each do |node|
      if heading?(node)
        current = { heading: node.text.strip, nodes: [] }
        sections << current
      elsif current
        current[:nodes] << node
      else
        lead_nodes << node
      end
    end

    [ serialize(lead_nodes).presence, build_sections(sections) ]
  end

  private

  attr_reader :html

  def fragment
    Nokogiri::HTML.fragment(html)
  end

  def heading?(node)
    node.element? && node.name == "h3"
  end

  def build_sections(sections)
    sections.map { |section| Section.new(heading: section[:heading], body_html: serialize(section[:nodes])) }
  end

  def serialize(nodes)
    nodes.map(&:to_html).join
  end
end
