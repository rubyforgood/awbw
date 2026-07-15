module SectorTagging
  # Tags a person's sectors and mirrors them onto the organizations they're
  # tied to. Organizations aggregate sectors across many members and have no
  # single "primary", so a person's primary + additional sectors are all unioned
  # onto each org as additional tags rather than churning the org's primary.
  #
  # Shared by registration (a person's primary + additional selections onto the
  # org they registered with) and "Other" sector-response promotion (an existing
  # response's sector onto the person and their orgs — always additional only).
  def self.apply(person:, organizations:, primary_ids: [], additional_ids: [])
    primary_ids = Array(primary_ids)
    additional_ids = Array(additional_ids)
    return if primary_ids.empty? && additional_ids.empty?

    person.tag_sectors(primary_ids: primary_ids, additional_ids: additional_ids)

    Array(organizations).compact.each do |organization|
      organization.tag_sectors(primary_ids: [], additional_ids: primary_ids + additional_ids)
    end
  end
end
