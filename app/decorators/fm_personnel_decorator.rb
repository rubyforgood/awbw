class FmPersonnelDecorator < ApplicationDecorator
  def kind
    data["Role"].presence || "Personnel"
  end

  def summary
    [ program, *data.values_at("Status", "AgreementStatus") ].compact_blank.join(" · ")
  end

  private

  def program
    project = FmProject.find_by(fm_id: data["ProjectID"])
    return data["ProjectID"] unless project

    organization = FmOrganization.find_by(fm_id: project.data["OrgID"])&.name
    [ project.name, organization ].compact_blank.join(" at ")
  end
end
