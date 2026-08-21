# Legacy field-identifier registration form (dev-only).
#
# The professional sector questions still accept one *legacy* field_identifier —
# "primary_sector_single" for the single-select primary sector — so older forms
# keep working (see FormField::PRIMARY_SECTOR_FIELD_IDENTIFIERS). The canonical
# combination already ships as "Training Registration Form"; this extra standalone
# form carries the legacy primary identifier, with a demo registrant + submission
# + tags, so every surface (form rendering, the form submission show, and the
# registrant's profile/edit pages) can be eyeballed on real data.
#
# The additional sector field and both age-group fields have never been renamed,
# so they stay canonical.
#
# Loaded last in the dev seed order so its extra role: "registration" form can't
# shadow the canonical one that events_management.rb / scholarships.rb look up via
# `Form.standalone.find_by(role: "registration")`. Idempotent throughout.

puts "Creating legacy field-identifier registration form…"

# The dynamic option pools, mirroring the canonical lists. The single-select
# primary sector field omits the catch-all "Other"; the additional sector field
# keeps it (offered as a folded "Other: <text>"). Age groups have no catch-all.
concrete_sectors = Sector.published.excluding_other.order(:name).to_a
other_sector = Sector.published.find_by(name: Sector::OTHER_SECTOR_NAME)
age_categories = Category.age_ranges.published.order(:position, :name).to_a

form_name = "Training Registration Form (legacy primary sector name)"

form = Form.standalone.find_by(name: form_name)
unless form
  form = FormBuilderService.new(
    name: form_name,
    sections: %i[person_identifier professional_info],
    role: "registration"
  ).call
  # Rename the canonical primary sector field onto its still-accepted legacy name.
  form.form_fields.find_by(field_identifier: "primary_sector")&.update!(field_identifier: "primary_sector_single")
end

# A demo registrant whose submission + tags back the form, so the profile and
# submission pages have data to render for this scheme.
person = Person.find_or_create_by!(email: "legacy.primary@example.com") do |p|
  p.first_name = "Morgan"
  p.last_name = "Legacyprimary"
end

submission = FormSubmission.find_or_create_by!(form: form, person: person, role: "registration")

primary_sector = concrete_sectors.first
additional_sectors = concrete_sectors.drop(1).first(2)
primary_age = age_categories.first
additional_ages = age_categories.drop(1).first(2)

# Mirror how public registration stores the answers: a single id for the
# dropdowns, ", "-joined ids for the checkboxes, and a folded "Other: <text>" for
# the additional sectors so the free-text path is represented too.
additional_sector_value = (additional_sectors.map(&:id) +
  [ ("Other: Equine-assisted therapy" if other_sector) ].compact).join(", ")
{
  "primary_sector_single" => primary_sector&.id&.to_s,
  "additional_sectors" => additional_sector_value.presence,
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
