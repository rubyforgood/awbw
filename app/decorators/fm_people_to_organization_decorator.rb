class FmPeopleToOrganizationDecorator < ApplicationDecorator
  def kind
    data["Title"].presence || "Affiliation"
  end

  def summary
    [ organization, *h.fm_date_labels(entered: data["DateEntered"], modified: data["ModificationTimeStamp"]) ].compact_blank.join(" · ")
  end

  private

  def organization
    org_id = data["OrgID"]
    FmOrganization.find_by(fm_id: org_id)&.name || org_id
  end
end
