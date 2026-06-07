module GrantHelper
  # Renders a grant's funder (donor) as an icon + name: a person icon tinted
  # in the people theme color, or a building icon tinted in the organizations
  # theme color.
  def grant_donor_badge(grant)
    return "" unless grant&.donor

    person = grant.donor.is_a?(Person)
    icon_name = person ? "fa-user" : "fa-building"
    color_key = person ? :people : :organizations

    tag.span(class: "inline-flex items-center gap-2") do
      safe_join([
        tag.i(class: "fa-solid #{icon_name} #{DomainTheme.text_class_for(color_key)}", aria: { hidden: "true" }),
        tag.span(grant.funder_name)
      ])
    end
  end
end
