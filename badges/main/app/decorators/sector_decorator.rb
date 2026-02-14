class SectorDecorator < ApplicationDecorator
  def title
    name
  end

  def detail(length: nil)
    "Sector: #{name}"
  end
end
