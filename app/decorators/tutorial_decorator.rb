class TutorialDecorator < ApplicationDecorator
  delegate_all

  def display_text
    "<div class='reset-list-items'>#{rhino_body}</div>".html_safe
  end

  def detail(length: nil)
    text = rhino_body&.to_plain_text
    length ? text&.truncate(length) : text
  end
end
