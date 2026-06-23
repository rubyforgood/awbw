class OrganizationTypeDecorator < ApplicationDecorator
  def title
    name
  end

  def detail(length: nil)
    "Organization type: #{name}"
  end
end
