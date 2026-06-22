module ScholarshipHelper
  # Funder label for a funder group on the scholarship index: the donor's name
  # with a person/organization icon, mirroring grant_donor_badge. Grant-free
  # ("Unfunded") groups have no donor, so they render the plain label.
  def funder_badge(funder_group)
    donor = funder_group.donor
    return tag.span(funder_group.name) unless donor

    person = donor.is_a?(Person)
    icon_name = person ? "fa-user" : "fa-building"
    color_key = person ? :people : :organizations

    tag.span(class: "inline-flex items-center gap-2") do
      safe_join([
        tag.i(class: "fa-solid #{icon_name} #{DomainTheme.text_class_for(color_key)}", aria: { hidden: "true" }),
        tag.span(funder_group.name)
      ])
    end
  end
end
