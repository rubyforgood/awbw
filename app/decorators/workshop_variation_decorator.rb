class WorkshopVariationDecorator < ApplicationDecorator
  def breadcrumbs
    "#{workshop_link} >> #{name}".html_safe
  end

  def detail(length: nil)
    length ? description&.truncate(length) : description
  end

  def default_display_image
    return workshop.primary_asset.file if workshop.respond_to?(:primary_asset) && workshop.primary_asset&.file&.attached?
    "workshop_default.jpg"
  end

  def display_code
    if legacy
      html = Nokogiri::HTML(code)
      html.xpath("//img").each do |img|
        src = img.attributes["src"]
        img.set_attribute("src", src)
      end
      html.xpath("//a").each do |link|
        href = link.attributes["href"].value.prepend("http://awbw.org")
        link.set_attribute("href", href)
        link.set_attribute("class", "underline")
      end
      html.to_s.html_safe
    else
      code
    end
  end

  private

  def method_name
  end

  def workshop_link
    h.link_to "#{workshop.title}", h.workshop_path(workshop)
  end
end
