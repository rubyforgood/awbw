class WindowsTypeDecorator < ApplicationDecorator
  def title
    name
  end

  def detail(length: nil)
    short_name
  end
end
