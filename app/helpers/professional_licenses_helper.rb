module ProfessionalLicensesHelper
  # Where the license edit form (eyebrow, Cancel, and the controller's post-save
  # redirect) returns to. Reached from a person's edit page (return_to=person) it
  # lands back on that person's licenses section; otherwise the licenses index.
  def professional_license_return_path(license)
    if params[:return_to] == "person" && license.person
      edit_person_path(license.person, anchor: "professional-licenses")
    elsif params[:return_to] == "ce_registration" && params[:ce_registration_id].present?
      edit_continuing_education_registration_path(params[:ce_registration_id])
    else
      professional_licenses_path
    end
  end

  # Eyebrow label for the license form back-link, matching whichever origin it was
  # reached from.
  def professional_license_return_label(license)
    if params[:return_to] == "person" && license.person
      license.person.full_name
    elsif params[:return_to] == "ce_registration" && params[:ce_registration_id].present?
      "CE registration"
    else
      "Licenses"
    end
  end
end
