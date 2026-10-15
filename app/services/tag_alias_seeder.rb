# Records what each legacy word for a sector or age group resolves to, as TagAlias rows.
# The tables are ADR-0007; this is them as data, so an import can look a term up and a
# reader can still see what a tag used to be called elsewhere. Idempotent: a term already
# recorded for a tag is left alone, including whatever an admin has added by hand.
#
# A term the portal already answers to by name needs no row — the lookup matches a tag's
# own name first, case-insensitively, and drops a trailing parenthetical. Only wording
# that differs is recorded here.
class TagAliasSeeder
  # The archive's own three fields. Settings describes where a facilitator works, so only
  # the ones that also say who they serve resolve; the rest are in DROPPED_SETTINGS.
  FILEMAKER_SECTORS = {
    "Community Oppression/Violence" => "Community Violence",
    "Criminal/Legal" => "Court/Legal System",
    "Foster Care" => "Foster Care/Adoption",
    "Student Services" => "Education",
    "Substance Abuse" => "Substance Use/Recovery",
    "Clinical Setting" => "Mental Health",
    "Educational Setting" => "Education",
    "Faith-Based Setting" => "Religious/Faith-Based",
    "Hospitals" => "Health/Medical",
    "Law Enforcement/Court" => "Court/Legal System",
    "Prisons/Jails" => "Incarceration",
    "Private Practice" => "Private Practice/Sole Proprietor",
    "With Staff" => "Staff/Organizational Development",
    "school" => "Education",
    "Students" => "Education",
    "Climate/Environmental Trauma" => "Climate/Environmental",
    "Illness" => "Health/Medical",
    "Pandemic-Related Stress" => "Health/Medical",
    "Mental Health Needs" => "Mental Health",
    "Suicidality" => "Mental Health",
    "Military/Veteran" => "Military/Veterans",
    "Oppression Against LGBTQIA+" => "LGBTQIA+",
    "People Who Do Harm/Batterers" => "Batterers Intervention",
    "Racism and Marginalization" => "Racial/Social Justice",
    "Religious Trauma" => "Religious/Faith-Based",
    "Secondary/Vicarious Trauma" => "Staff/Organizational Development",
    "Student-Related Stress" => "Education",
    "Victims of Crime" => "Court/Legal System",
    "LGBTQIA +" => "LGBTQIA+"
  }.freeze

  # The forms asked the same questions in prose. Their labels carry a "services" suffix or
  # different wording, so each needs its own term; the parentheticals resolve on their own.
  FORM_SECTORS = {
    "Community oppression/violence services" => "Community Violence",
    "Criminal/legal services" => "Court/Legal System",
    "Disability services" => "Disability Services",
    "Domestic violence services" => "Domestic Violence",
    "Foster care/adoption services" => "Foster Care/Adoption",
    "Homeless services" => "Homelessness",
    "Human trafficking services" => "Human Trafficking",
    "Immigration services" => "Immigration",
    "Incarceration services" => "Incarceration",
    "Indigenous/tribal nation services" => "Indigenous/Tribal Nation",
    "LGBTQIA+ services" => "LGBTQIA+",
    "Mental health services" => "Mental Health",
    "Reproductive services" => "Reproductive Services",
    "Restorative/transformative justice services" => "Restorative/Transformative Justice",
    "Sexual assault services" => "Sexual Assault",
    "Student services" => "Education",
    "Substance use services" => "Substance Use/Recovery",
    "Substance use" => "Substance Use/Recovery",
    "Foster care/adoption" => "Foster Care/Adoption",
    "Law enforcement/court/legal" => "Court/Legal System"
  }.freeze

  # Hand-typed cells that name more than one sector, so each resolves to all of them —
  # the same one-to-many shape as "C & T". Only recorded where every concept in the cell is
  # already a decided term, so nothing new is being inferred.
  COMPOUND_SECTORS = {
    "Domestic Violence & Homelessness" => [ "Domestic Violence", "Homelessness" ],
    "Sexual Assault & Domestic Violence" => [ "Sexual Assault", "Domestic Violence" ],
    "Domestic Violence, Sexual Assault" => [ "Domestic Violence", "Sexual Assault" ],
    "Domestic Violence and Sexual Assault survivors" => [ "Domestic Violence", "Sexual Assault" ],
    "Domestic and Sexual Violence Families" => [ "Domestic Violence", "Sexual Assault" ],
    "Sexual and Domestic Violence Agency" => [ "Sexual Assault", "Domestic Violence" ],
    "DV/SA/other related crimes" => [ "Domestic Violence", "Sexual Assault" ],
    "Dual Agency Domestic violence/Sexual assault/ Human trafficking" =>
      [ "Domestic Violence", "Sexual Assault", "Human Trafficking" ],
    "Immigration, Health, Prevention of Violence and Education" => [ "Immigration", "Health/Medical", "Education" ],
    "Addiction, Native Americans, mental health and addiction" =>
      [ "Substance Use/Recovery", "Indigenous/Tribal Nation", "Mental Health" ],
    "Education, SEL needs" => [ "Education" ],
    "Hospice, end of life, bereavement" => [ "Grief/Loss" ]
  }.freeze

  # A retired sector an alias deliberately points at. The term is in the archive 634 times
  # and the tag it means still exists, unpublished, carrying the taggings it already had —
  # so the term resolves even though nothing new can be tagged with it by name.
  RETIRED_SECTORS = { "Poverty" => "Poverty" }.freeze

  STORY_SHARE_SECTORS = {
    "Advocacy" => "Systems/Policy Change",
    "Child Abuse / Neglect" => "Child Abuse/Neglect",
    "Community Engagement" => "Community Building",
    "Court & Legal System" => "Court/Legal System",
    "Donor Engagement" => "Fundraising/Donor Engagement",
    "Foster Care" => "Foster Care/Adoption",
    "Grief & Loss" => "Grief/Loss",
    "Military & Veterans" => "Military/Veterans",
    "Physical & Terminal Illness" => "Health/Medical",
    "Schools & Universities" => "Education",
    "Self-Care & Personal Growth" => "Self-Care/Personal Growth",
    "Social Justice" => "Racial/Social Justice",
    "Staff & Organizational Development" => "Staff/Organizational Development",
    "Substance Abuse Recovery" => "Substance Use/Recovery"
  }.freeze

  # Names the portal itself used before the 2026 consolidation renamed and merged them.
  PORTAL_SECTORS = {
    "Child abuse" => "Child Abuse/Neglect",
    "Children of Domestic Violence Survivors" => "Domestic Violence",
    "Community oppression/violence" => "Community Violence",
    "Criminal/legal" => "Court/Legal System",
    "Disabled" => "Disability Services",
    "Disabled Person" => "Disability Services",
    "Disability" => "Disability Services",
    "Education/schools" => "Education",
    "Family Violence" => "Domestic Violence",
    "Foster children/APPS" => "Foster Care/Adoption",
    "Foster Youth" => "Foster Care/Adoption",
    "Grief and loss" => "Grief/Loss",
    "Mental illness" => "Mental Health",
    "Reproductive" => "Reproductive Services",
    "Serious illness" => "Health/Medical",
    "Staff & organizational development" => "Staff/Organizational Development",
    "Student" => "Education",
    "Substance use" => "Substance Use/Recovery",
    "Veterans & military" => "Military/Veterans"
  }.freeze

  # A term can name several age groups, so these are lists: serving families is serving
  # every age, and a person has no population tag to carry "Families" on its own.
  #
  # Some of these terms come from the *sector* fields, because the vocabularies cross — a
  # life experience of elder abuse says the person serves elders, and a service area of
  # children's services says they serve children. Whether the tag lands as primary or
  # additional follows from the field the term sat in, not from the term.
  FILEMAKER_AGE_GROUPS = {
    "Families" => %w[Children Teens Adults Elders],
    "Elder Abuse" => %w[Elders],
    "Children's Services" => %w[Children],
    "C & T" => %w[Children Teens],
    "Children & Teens" => %w[Children Teens],
    "Adults & Children" => %w[Adults Children],
    "Adults 18+" => %w[Adults],
    "18+" => %w[Adults],
    "13-17" => %w[Teens],
    "6-12" => %w[Children],
    "3-5" => %w[Children],
    "Young Children" => %w[Children]
  }.freeze

  STORY_SHARE_AGE_GROUPS = { "Adult" => %w[Adults] }.freeze

  # Terms that name no tag on purpose: a setting that says where or how someone works
  # rather than who they serve, an answer that says nothing at all, and one life experience
  # (war) that AWBW chose to leave untagged. Recorded so they don't sit in the queue of
  # terms still needing a decision.
  IGNORED_TERMS = [
    "Community-Based", "Events and Conferences", "Events & Conferences", "Home Visits",
    "Outreach Program", "Residential Program", "Virtually", "Other", "Did not specify",
    "Residential", "In person", "In visits", "virtually & in-person", "At office", "Office space.",
    "On-Call/Crisis", "Support groups", "n/a", "none", "something", "unsure", "Everyone", "Technology",
    "People Who Have Experienced War"
  ].freeze

  def self.call(...)
    new(...).call
  end

  def initialize(quiet: false)
    @quiet = quiet
    @created = 0
    @missing = []
  end

  def call
    record_sectors(FILEMAKER_SECTORS, "filemaker")
    record_sectors(COMPOUND_SECTORS, "filemaker")
    record_retired_sectors(RETIRED_SECTORS, "filemaker")
    record_sectors(FORM_SECTORS, "forms")
    record_sectors(STORY_SHARE_SECTORS, "story_share")
    record_sectors(PORTAL_SECTORS, "portal")
    record_age_groups(FILEMAKER_AGE_GROUPS, "filemaker")
    record_age_groups(STORY_SHARE_AGE_GROUPS, "story_share")
    record_ignored(IGNORED_TERMS, "filemaker")
    report
    self
  end

  private

  def record_sectors(table, source)
    table.each do |term, names|
      Array(names).each { |name| record(term, "Sector", sector_ids[name.downcase], source, name) }
    end
  end

  # Resolved against every sector, published or not: the point of the table is the ones that
  # aren't, which the published lookup would report as missing.
  def record_retired_sectors(table, source)
    table.each { |term, name| record(term, "Sector", every_sector_id[name.downcase], source, name) }
  end

  def record_age_groups(table, source)
    table.each do |term, names|
      names.each { |name| record(term, "Category", age_group_ids[name.downcase], source, name) }
    end
  end

  def record_ignored(terms, source)
    terms.each do |term|
      alias_row = TagAlias.find_or_initialize_by(name: term.squish, aliasable_type: nil, aliasable_id: nil)
      next unless alias_row.new_record?

      alias_row.update!(source: source, ignored: true)
      @created += 1
    end
  end

  def record(term, type, id, source, name)
    return @missing << name unless id

    alias_row = TagAlias.find_or_initialize_by(name: term.squish, aliasable_type: type, aliasable_id: id)
    return unless alias_row.new_record?

    alias_row.update!(source: source)
    @created += 1
  end

  # Published only, the same vocabulary TagTranslation resolves against, so a term aimed at
  # a retired tag is reported rather than recorded as an alias that never resolves.
  def sector_ids
    @sector_ids ||= Sector.published.pluck(:name, :id).to_h { |name, id| [ name.downcase, id ] }
  end

  def age_group_ids
    @age_group_ids ||= Category.age_ranges.published.pluck(:name, :id).to_h { |name, id| [ name.downcase, id ] }
  end

  def every_sector_id
    @every_sector_id ||= Sector.pluck(:name, :id).to_h { |name, id| [ name.downcase, id ] }
  end

  def report
    return if @quiet

    puts "  #{@created} tag aliases added (#{TagAlias.count} recorded)"
    puts "  no published tag named: #{@missing.uniq.sort.join(', ')} — seed the sectors and age ranges first" if @missing.any?
  end
end
