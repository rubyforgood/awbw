class TutorialDecorator < ApplicationDecorator
  delegate_all

  def display_text
    "<div class='reset-list-items'>#{body}</div>".html_safe
  end

  def detail(length: nil)
    length ? body&.truncate(length) : body
  end
end
