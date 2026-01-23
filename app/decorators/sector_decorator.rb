class SectorDecorator < ApplicationDecorator
  def title
    name
  end

  def detail(length: nil)
    "Service population: #{name}"
  end
end
