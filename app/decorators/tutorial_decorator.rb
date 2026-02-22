class TutorialDecorator < Draper::Decorator
  delegate_all

  def display_text
    "<div class='reset-list-items'>#{body}</div>".html_safe
  end

  def detail(length: nil)
    length ? body&.truncate(length) : body
  end

  def default_display_image
    "theme_default.png"
  end
end
