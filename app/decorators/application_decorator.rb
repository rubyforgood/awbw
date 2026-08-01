class ApplicationDecorator < Draper::Decorator
  delegate_all

  def display_image
    return primary_asset.file if object.respond_to?(:primary_asset) && primary_asset&.file&.attached?
    return downloadable_asset.file if object.respond_to?(:downloadable_asset) && downloadable_asset&.file&.attached?
    return gallery_assets.first.file if object.respond_to?(:gallery_assets) && gallery_assets.first&.file&.attached?
    default_display_image
  end

  def default_display_image
    "theme_default.png"
  end

  def link_target
    h.polymorphic_path(object)
  end

  def published?
    object.respond_to?(:published?) ? object.published? : true
  end

  def external_link?
    false
  end

  # One-line summary of the tagged sectors for a collapsed form section, primary
  # first. The primary sector is bold with a ⭐; a sector leader gets a 👑 and a
  # trailing "(sector leader)". Excludes the "Other" catch-all. HTML-safe.
  def sectors_summary
    items = object.sectorable_items_primary_first.reject { |item| item.sector&.name == Sector::OTHER_SECTOR_NAME }
    return "None selected" if items.empty?

    h.safe_join(items.map { |item| sector_summary_chip(item) }, ", ")
  end

  private

  def sector_summary_chip(item)
    name = item.sector&.name.to_s
    pieces = []
    pieces << h.content_tag(:i, "", class: "fa-solid fa-crown text-lime-600") if item.is_leader?
    pieces << h.content_tag(:i, "", class: "fa-solid fa-star text-amber-400") if item.is_primary?
    pieces << (item.is_primary? ? h.content_tag(:strong, name) : name)
    pieces << "(sector leader)" if item.is_leader?
    h.safe_join(pieces, " ")
  end
end
