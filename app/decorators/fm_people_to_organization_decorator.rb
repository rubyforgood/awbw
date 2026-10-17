class FmPeopleToOrganizationDecorator < ApplicationDecorator
  def kind
    data["Title"].presence || "Affiliation"
  end

  def summary
    org_id = data["OrgID"]
    FmOrganization.find_by(fm_id: org_id)&.name || org_id
  end
end
