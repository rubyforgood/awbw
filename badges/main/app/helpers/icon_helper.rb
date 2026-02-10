module IconHelper
  def icon(name, **options)
    path = Rails.root.join("app/frontend/icons/#{name}.svg")
    return "" unless File.exist?(path)

    svg = File.read(path)
    doc = Nokogiri::HTML::DocumentFragment.parse(svg)
    svg_el = doc.at_css("svg")

    if options[:title]
      title_el = svg_el.at_css("title")

      if title_el
        title_el.content = options[:title]
      else
        svg_el.prepend_child("<title>#{ERB::Util.html_escape(options[:title])}</title>")
      end

      options.delete(:title)
    end

    options.each { |attr, value| svg_el[attr.to_s] = value }

    doc.to_html.html_safe
  end
end
