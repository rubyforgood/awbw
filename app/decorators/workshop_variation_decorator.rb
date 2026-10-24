class WorkshopVariationDecorator < ApplicationDecorator
  def detail(length: nil)
    length ? description&.truncate(length) : description
  end

  def default_display_image
    return workshop.primary_asset.file if workshop.respond_to?(:primary_asset) && workshop.primary_asset&.file&.attached?
    "workshop_default.jpg"
  end

  def display_body
    if legacy
      html = Nokogiri::HTML(body)
      html.xpath("//img").each do |img|
        src = img.attributes["src"]
        img.set_attribute("src", src)
      end
      html.xpath("//a").each do |link|
        href = link.attributes["href"].value.prepend(Setting.organization_website.to_s.chomp("/"))
        link.set_attribute("href", href)
        link.set_attribute("class", "underline")
      end
      html.to_s.html_safe
    else
      body
    end
  end
end
