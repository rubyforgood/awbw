class OrganizationUserDecorator < ApplicationDecorator
  def detail(length: nil)
    "#{user.full_name}: #{title.presence || position} - #{organization.name}"
  end
end
