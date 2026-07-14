# Parses admin-authored callout HTML into an ordered list of segments so every
# callout content page renders the same way: plain rich text, with any <toggle>
# element turned into a styled collapsible section.
#
# Admins write a toggle as a custom <toggle> element in the plain-HTML field,
# giving the summary either as a title attribute or a leading <summary>:
#
#     <toggle title="Workshop 1"><ul><li>Clear glass stones</li></ul></toggle>
#     <toggle><summary>Workshop 1</summary><ul><li>Clear glass stones</li></ul></toggle>
#
# The <toggle>/<summary> tags are consumed here, before the body is handed to the
# form_label_html sanitizer, so the disclosure markup (which that allowlist would
# strip on save) is built in code and can never be lost. Content with no <toggle>
# comes back as a single :html segment and renders unchanged.
class CalloutContent
  # One rendered piece: a :html run of plain rich text, or a :toggle whose
  # `summary` is the always-visible heading and `html` the revealed body.
  Segment = Data.define(:type, :summary, :html)

  def self.segments(html)
    new(html).segments
  end

  def initialize(html)
    @html = html.to_s
  end

  # Walks the top-level nodes, buffering plain content and breaking out a toggle
  # segment at each <toggle> element, preserving original order.
  def segments
    result = []
    buffer = []
    fragment.children.each do |node|
      if toggle?(node)
        flush(buffer, result)
        result << toggle_segment(node)
      else
        buffer << node
      end
    end
    flush(buffer, result)
    result
  end

  private

  attr_reader :html

  def fragment
    Nokogiri::HTML.fragment(html)
  end

  def toggle?(node)
    node.element? && node.name == "toggle"
  end

  # Emit the buffered non-toggle nodes as one plain-HTML segment, dropping a run
  # that's only whitespace so we never render an empty prose block.
  def flush(buffer, result)
    nodes = buffer.dup
    buffer.clear
    joined = nodes.map(&:to_html).join
    result << Segment.new(type: :html, summary: nil, html: joined) if joined.present?
  end

  # Summary from the title attribute, else a leading <summary> child (removed
  # from the body), else a generic fallback so an untitled toggle still opens.
  def toggle_segment(node)
    summary_el = node.at_xpath("./summary")
    summary = node["title"].presence || summary_el&.text&.strip
    summary_el&.remove
    Segment.new(type: :toggle, summary: summary.presence || "Details", html: node.inner_html)
  end
end
