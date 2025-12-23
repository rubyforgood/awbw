class SectorDecorator < ApplicationDecorator

  def title
    name
  end

  def detail
    "Service population: #{name}"
  end
end
