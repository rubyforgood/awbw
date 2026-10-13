module SubmissionTagging
  # Applies a submission's primary/additional selections to the respondent and
  # mirrors them onto the organizations they're tied to. `tag_with:` picks which
  # taggable the selections belong to — :tag_sectors (SectorsTaggable) or
  # :tag_age_groups (AgeGroupTaggable) — so both follow one rule.
  #
  # Organizations aggregate tags across many members and read a member's primary
  # off that member, so a person's primary + additional selections are all
  # unioned onto each org as additional tags. Passing no primary to the org is
  # what keeps the mirror additive: a primary selection reassigns the
  # respondent's own primary, and must not churn an org's.
  #
  # `replace_person: true` overwrites the respondent's own tags with the
  # submitted set (the newest submission is the freshest source).
  #
  # Shared by the submission pipelines (a person's selections onto the org they
  # named) and "Other" sector-response promotion (an existing response's sector
  # onto the person and their orgs — always additional only).
  def self.apply(person:, organizations:, tag_with:, primary_ids: [], additional_ids: [], replace_person: false)
    primary_ids = Array(primary_ids)
    additional_ids = Array(additional_ids)
    return if primary_ids.empty? && additional_ids.empty?

    person.public_send(tag_with, primary_ids: primary_ids, additional_ids: additional_ids, replace: replace_person)

    Array(organizations).compact.each do |organization|
      organization.public_send(tag_with, primary_ids: [], additional_ids: primary_ids + additional_ids)
    end
  end
end
