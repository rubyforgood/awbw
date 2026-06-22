# Legacy field-identifier registration forms (dev-only).
#
# The four professional questions — primary/additional sector and
# primary/additional age group — resolve their options dynamically from Sector /
# AgeRange records, and the code still accepts several *legacy* field_identifiers
# for the sector fields so older forms keep working (see
# FormField::PRIMARY_SECTOR_FIELD_IDENTIFIERS / ADDITIONAL_SECTOR_FIELD_IDENTIFIERS).
# The canonical combination already ships as "Training Registration Form"; these
# extra standalone forms each carry a different legacy combination, with a demo
# registrant + submission + tags, so every surface (form rendering, the form
# submission show, and the registrant's profile/edit pages) can be eyeballed on
# real data for every identifier scheme.
#
# Loaded last in the dev seed order so its extra role: "registration" forms can't
# shadow the canonical one that events_management.rb / scholarships.rb look up via
# `Form.standalone.find_by(role: "registration")`. Idempotent throughout.

puts "Creating legacy field-identifier registration forms…"

# The dynamic option pools, mirroring the canonical lists. The single-select
# "primary" fields omit the catch-all ("Other" sector / "Mixed-age groups"). The
# additional sector field keeps "Other" (offered as a folded "Other: <text>"),
# but the additional age field — like the primary — drops "Mixed-age groups".
concrete_sectors = Sector.published.excluding_other.order(:name).to_a
other_sector = Sector.published.find_by(name: Sector::OTHER_SECTOR_NAME)
concrete_ages = Category.age_ranges.published.excluding_mixed_age.order(:position, :name).to_a

# Each scheme renames the two canonical sector fields onto a legacy combination.
# The age-group fields have never been renamed, so they stay canonical.
legacy_schemes = [
  { suffix: "legacy service area",
    primary_sector: "primary_service_area_single", additional_sector: "primary_service_area",
    first_name: "Lee", last_name: "Servicearea", email: "legacy.servicearea@example.com" },
  { suffix: "legacy additional name",
    primary_sector: "primary_sector_single", additional_sector: "primary_sector",
    first_name: "Morgan", last_name: "Additionalname", email: "legacy.additional@example.com" },
  { suffix: "legacy mixed",
    primary_sector: "primary_service_area_single", additional_sector: "additional_sectors",
    first_name: "Rae", last_name: "Mixedscheme", email: "legacy.mixed@example.com" }
]

legacy_schemes.each_with_index do |scheme, i|
  form_name = "Training Registration Form (#{scheme[:suffix]})"

  form = Form.standalone.find_by(name: form_name)
  unless form
    form = FormBuilderService.new(
      name: form_name,
      sections: %i[person_identifier professional_info],
      role: "registration"
    ).call
    { "primary_sector_single" => scheme[:primary_sector],
      "additional_sectors" => scheme[:additional_sector] }.each do |canonical, legacy|
      next if canonical == legacy
      form.form_fields.find_by(field_identifier: canonical)&.update!(field_identifier: legacy)
    end
  end

  # A demo registrant whose submission + tags back the form, so the profile and
  # submission pages have data to render for this scheme.
  person = Person.find_or_create_by!(email: scheme[:email]) do |p|
    p.first_name = scheme[:first_name]
    p.last_name = scheme[:last_name]
  end

  submission = FormSubmission.find_or_create_by!(form: form, person: person, role: "registration")

  primary_sector = concrete_sectors[i % concrete_sectors.size] if concrete_sectors.any?
  additional_sectors = concrete_sectors.rotate(i + 1).reject { |sector| sector == primary_sector }.first(2)
  primary_age = concrete_ages[i % concrete_ages.size] if concrete_ages.any?
  # Additional age groups omit the catch-all "Mixed-age groups" (same as the
  # primary field), so draw the extras from the concrete ranges too.
  additional_ages = concrete_ages.rotate(i + 1).reject { |age| age == primary_age }.first(2)

  # Mirror how public registration stores the answers: a single id for the
  # dropdowns, ", "-joined ids for the checkboxes, and a folded "Other: <text>" for
  # the additional sectors so the free-text path is represented too.
  additional_sector_value = (additional_sectors.map(&:id) +
    [ ("Other: Equine-assisted therapy" if other_sector) ].compact).join(", ")
  {
    scheme[:primary_sector] => primary_sector&.id&.to_s,
    scheme[:additional_sector] => additional_sector_value.presence,
    "primary_age_group" => primary_age&.id&.to_s,
    "additional_age_group" => additional_ages.map(&:id).join(", ").presence
  }.each do |identifier, value|
    next if value.blank?
    field = form.form_fields.find_by(field_identifier: identifier)
    next unless field
    next if submission.form_answers.where(form_field: field).any?
    submission.form_answers.create!(form_field: field,
                                    submitted_answer: value,
                                    question_name_when_answered: field.name)
  end

  # Tag the registrant with the same primary/additional split assign_tags applies,
  # so the profile/edit pages crown the right primary and list the additional ones.
  person.tag_sectors(primary_ids: [ primary_sector&.id ].compact, additional_ids: additional_sectors.map(&:id))
  person.tag_age_groups(primary_ids: [ primary_age&.id ].compact, additional_ids: additional_ages.map(&:id))
end
