class ResourceDecorator < ApplicationDecorator
  def detail(length: nil)
    text = rhino_body&.to_plain_text
    length ? text&.truncate(length) : text
  end

  def default_display_image
    kind.downcase.to_sym
  end

  def kind_display
    kind == "Scholarship" ? "Scholar-ship" : (kind.present? ? kind.titleize : "Resource")
  end

  def truncated_author
    h.truncate credited_author_name, length: 20
  end

  # Name shown on the author/credit line: the chosen person's credit when a
  # person author is set, otherwise the preserved legacy free-text author,
  # otherwise the creating user's person credit (AuthorCreditable fallback).
  def credited_author_name
    return author_credit if author.present?
    legacy_author_name.presence || author_credit
  end

  # The person to link the credit to, when there is a linkable one. A legacy
  # free-text author is just a string, so it links nowhere.
  def credited_author_link_person
    return author if author.present?
    return nil if legacy_author_name.present?
    created_by&.person
  end

  def truncated_title
    h.truncate title, length: 25
  end

  def truncated_text(ln = 100)
    h.truncate(rhino_body.to_plain_text, length: ln)
  end

  def display_title
    title || kind
  end

  def flex_text
    h.truncate(rhino_body.to_plain_text, length: 200)
  end

  def breadcrumbs
    "#{type_link} >> #{title}".html_safe
  end

  def author_full_name
    credited_author_name
  end

  def display_date
    created_at.strftime("%B %Y")
  end

  def display_text
    "<div class='reset-list-items'>#{rhino_body}</div>".html_safe
  end

  def card_class
    kind == "Theme" ? "circular-border" : "normal"
  end

  def toolkit_and_form?
    kind == "ToolkitAndForm"
  end

  private

  def html
    Nokogiri::HTML(rhino_body.to_s)
  end

  def type_link
    h.link_to "Resources", h.resources_path
  end
end
