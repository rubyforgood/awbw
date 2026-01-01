class TutorialDecorator < Draper::Decorator
  delegate_all

  def display_text
    "<div class='reset-list-items'>#{body}</div>".html_safe
  end
end
