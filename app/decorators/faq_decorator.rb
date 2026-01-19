class FaqDecorator < ApplicationDecorator
  def title
    question
  end

  def detail(length: nil)
    answer
  end
end
