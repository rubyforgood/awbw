module IconHelper
  def icon(name, **options)
    path = Rails.root.join("app/frontend/icons/#{name}.svg")
    return "" unless File.exist?(path)

    svg = File.read(path)
    doc = Nokogiri::HTML::DocumentFragment.parse(svg)
    svg_el = doc.at_css("svg")
    options.each { |attr, value| svg_el[attr.to_s] = value }

    doc.to_html.html_safe
  end
end
