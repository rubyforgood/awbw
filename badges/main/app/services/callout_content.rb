# Parses admin-authored callout HTML into an ordered list of segments so every
# callout content page renders the same way: plain rich text, with each
# collapsible disclosure turned into a styled toggle card.
#
# Admins write disclosures as standard HTML — exactly what an HTML generator or
# LLM produces — the leading <summary> is the heading, the rest is the body:
#
#     <details><summary>Workshop 1</summary><ul><li>Clear glass stones</li></ul></details>
#     <details open><summary>Workshop 1</summary>…</details>   (starts expanded)
#
# (<toggle> is accepted as an alias, and a `title` attribute as an alternative to
# a <summary> child.) The disclosure is rebuilt here into our styled card, so the
# look is consistent no matter how the markup was authored. <details>/<summary>
# are also on the form_label_html allowlist, so even content that skips this
# parser survives a save as a native disclosure rather than being stripped.
# Content with no disclosure comes back as a single :html segment, unchanged.
class CalloutContent
  # Elements treated as a collapsible section. <details> is the standard; <toggle>
  # is a friendly alias.
  TOGGLE_TAGS = %w[details toggle].freeze

  # One rendered piece: a :html run of plain rich text, or a :toggle whose
  # `summary` is the always-visible heading, `html` the revealed body, and `open`
  # whether it starts expanded.
  Segment = Data.define(:type, :summary, :html, :open)

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
    node.element? && TOGGLE_TAGS.include?(node.name)
  end

  # Emit the buffered non-toggle nodes as one plain-HTML segment, dropping a run
  # that's only whitespace so we never render an empty prose block.
  def flush(buffer, result)
    nodes = buffer.dup
    buffer.clear
    joined = nodes.map(&:to_html).join
    result << Segment.new(type: :html, summary: nil, html: joined, open: false) if joined.present?
  end

  # Summary from a leading <summary> child (removed from the body), else the title
  # attribute, else a generic fallback so an untitled disclosure still opens.
  def toggle_segment(node)
    summary_el = node.at_xpath("./summary")
    summary = summary_el&.text&.strip.presence || node["title"]
    summary_el&.remove
    Segment.new(type: :toggle, summary: summary.presence || "Details", html: node.inner_html, open: node.key?("open"))
  end
end
