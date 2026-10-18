# Records what each legacy word for a sector or age group resolves to, as TagAlias rows.
# The tables are ADR-0007; this is them as data, so an import can look a term up and a
# reader can still see what a tag used to be called elsewhere. Idempotent: a term already
# recorded for a tag is left alone, including whatever an admin has added by hand, and a
# proposed row the tables no longer name is withdrawn.
#
# A term the portal already answers to by name needs no row — the lookup matches a tag's
# own name first, case-insensitively, and drops a trailing parenthetical. Only wording
# that differs is recorded here.
class TagAliasSeeder
  # The archive's own three fields. Settings describes where a facilitator works, so only
  # the ones that also say who they serve resolve; the rest are in IGNORED_TERMS.
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
    "Racism & Marginalization" => "Racial/Social Justice",
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

  # Names the portal itself used before the 2026 consolidation renamed and merged them,
  # plus the consolidation sheet's "Sytems" spelling of the tag it proposed.
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
    "Sytems/Policy Change" => "Systems/Policy Change",
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
    "Community-Based", "Community based", "Events and Conferences", "Events & Conferences", "Home Visits",
    "Outreach Program", "Residential Program", "Virtually", "Other", "Did not specify",
    "Residential", "In person", "In visits", "virtually & in-person", "At office", "Office space.",
    "On-Call/Crisis", "Support groups", "n/a", "none", "something", "unsure", "Everyone", "Technology",
    "People Who Have Experienced War"
  ].freeze

  # ─── Proposed, pending staff validation ─────────────────────────────────────────────
  #
  # Semantic reads of the archive's hand-typed free text, not decisions AWBW has made. They
  # are seeded as `proposed`, so they resolve — an import shouldn't lose them — and
  # `TagAlias.proposed` is the list to walk with staff, term by term.
  #
  # Only terms whose meaning is plain are here. Anything naming an organization, a place
  # that identifies one, or a facilitator's own circumstances is left out: that text is
  # personal, and it belongs in the archive rather than copied into a catalogue.
  PROPOSED_SECTORS = {
    "1:1 children and youth who experience domestic violence, dating violence, or sexual abuse" =>
      [ "Domestic Violence", "Sexual Assault", "Child Abuse/Neglect" ],
    "a regularly meting group with a drop in attendance from the local queer community" => [ "LGBTQIA+" ],
    "Advocacy for survivors of domestic and sexual violence" => [ "Domestic Violence", "Sexual Assault" ],
    "Arts Education & Community Art Making" => [ "Education", "Community Building" ],
    "bereavement and complex care in hospital setting" => [ "Grief/Loss", "Health/Medical" ],
    "Cancer Survivorship" => [ "Health/Medical" ],
    "Cases opened by Child protective services" => [ "Child Abuse/Neglect", "Foster Care/Adoption" ],
    "Children's Advocacy Center Children & Families" => [ "Child Abuse/Neglect" ],
    "College campus" => [ "Education" ],
    "Community Morale" => [ "Community Building" ],
    "Community-based, youth diversion, juvenile hall" => [ "Incarceration", "Restorative/Transformative Justice" ],
    "Critically ill children" => [ "Health/Medical" ],
    "Day Program for adults with developmental and intellectual disabilities" => [ "Disability Services" ],
    "Disaster Recovery - Wellness through Trauma informed Activities" => [ "Climate/Environmental" ],
    "Domestic Violence Shelter" => [ "Domestic Violence" ],
    "Domestic Violence, Sexual Violence and Stalking Advocacy Center" => [ "Domestic Violence", "Sexual Assault" ],
    "DV Resource Center" => [ "Domestic Violence" ],
    "Empowerment community groups" => [ "Community Building" ],
    "Environmental education setting" => [ "Climate/Environmental" ],
    "First Responders. doing workshops in Fire Stations and Law Enforcement Offices" =>
      [ "Staff/Organizational Development" ],
    "formerly incarcerated/formerly gang related" => [ "Incarceration", "Community Violence" ],
    "Foster Care agencies" => [ "Foster Care/Adoption" ],
    "Grief support group" => [ "Grief/Loss" ],
    "Helping Professionals, Caregivers, Leaders" => [ "Staff/Organizational Development" ],
    "High level secondary art students" => [ "Education" ],
    "I intend to service a diverse population experiencing, DV, sexual assault, and homelessness" =>
      [ "Domestic Violence", "Sexual Assault", "Homelessness" ],
    "Immigration Clinic" => [ "Immigration" ],
    "In DV shelters" => [ "Domestic Violence" ],
    "Individual and Group counseling with students. In my office and in classrooms." =>
      [ "Education", "Mental Health" ],
    "Individual counseling sessions with sexual assault survivors." => [ "Sexual Assault", "Mental Health" ],
    "Inpatient Psychiatric Hopital" => [ "Mental Health" ],
    "Intellectual Disabilities" => [ "Disability Services" ],
    "Intensive Outpatient programs" => [ "Mental Health" ],
    "Interpersonal violence and any gender based harassment and discrimination" =>
      [ "Domestic Violence", "Sexual Assault" ],
    "LA Fire imacted Community Members in Palisades and Altadena" => [ "Climate/Environmental" ],
    "Life Coaching" => [ "Self-Care/Personal Growth" ],
    "Low-income housing /vulnerable population" => [ "Homelessness" ],
    "Low-income housing support services" => [ "Homelessness" ],
    "Maternal wellness and postpartum support" => [ "Reproductive Services" ],
    "Ministry Events" => [ "Religious/Faith-Based" ],
    "monthly and weekly events for survivors of incest, trafficking, clergy abuse, sexual assault, CSA" =>
      [ "Sexual Assault", "Human Trafficking", "Child Abuse/Neglect", "Religious/Faith-Based" ],
    "Native American and Alaska Native survivors of Domestic Violence, Sexual Assault, Human Sex Trafficking," =>
      [ "Indigenous/Tribal Nation", "Domestic Violence", "Sexual Assault", "Human Trafficking" ],
    "Open community - all residents regardless of age, background, or circumstances who are interested " \
      "in using art as a tool for personal healing and community connection" => [ "Community Building" ],
    "Organizations and their staff who work in the primary prevention of intimate partner violence" =>
      [ "Domestic Violence", "Staff/Organizational Development" ],
    "Parents and children of whom we receive a referral for, mostly DCF involved families" =>
      [ "Foster Care/Adoption" ],
    "Parents of children involved with DCF" => [ "Foster Care/Adoption" ],
    "personal development and life coaching" => [ "Self-Care/Personal Growth" ],
    "Political Assylum" => [ "Immigration" ],
    "Practical and therapeutic support for people struggling with grief, loss, existential distress" =>
      [ "Grief/Loss", "Mental Health" ],
    "Re-Entry/social and community based work" => [ "Incarceration" ],
    "Resident low income housing" => [ "Homelessness" ],
    "Restorative/Self-Care work with Faculty who teach inside of prisons/jails, as well as currently " \
      "incarcerated students" => [ "Incarceration", "Self-Care/Personal Growth", "Restorative/Transformative Justice" ],
    "Social services workers" => [ "Staff/Organizational Development" ],
    "Staff Burnout and Wellness" => [ "Staff/Organizational Development" ],
    "Student counseling groups" => [ "Education", "Mental Health" ],
    "Students, families and teachers impacted by the 2025 Los Angeles fires" =>
      [ "Climate/Environmental", "Education" ],
    "Supervised visitation sessions for foster youth with their biological parents" => [ "Foster Care/Adoption" ],
    "Supportive Housing" => [ "Homelessness" ],
    "Survivors with Disabilities ( Deafness)" => [ "Disability Services", "Domestic Violence" ],
    "Urban Native American Health Centers" => [ "Indigenous/Tribal Nation", "Health/Medical" ],
    "We are a Native American culturally specific dual sexual assault and domestic violence agency that " \
      "has programming for teens and adults, including elderly" =>
      [ "Indigenous/Tribal Nation", "Sexual Assault", "Domestic Violence" ],
    "Wellness and Prevention Programs and activities" => [ "Self-Care/Personal Growth" ],
    "Wellness Center" => [ "Self-Care/Personal Growth" ],
    "While training psychology practicum students." => [ "Education", "Staff/Organizational Development" ],
    "With DV agencies we support in Ohio and allied professionals addressing wellness practice, " \
      "organizational wellness and to inspire hope and creativity" =>
      [ "Domestic Violence", "Staff/Organizational Development" ],
    "With outreach with students experiencing homelessness. Aisde from my job as a liaison in the " \
      "education field, I also volunteer at homeless shleters for families and youth." =>
      [ "Homelessness", "Education" ],
    "With staff to practice- other: in the communities with families" => [ "Staff/Organizational Development" ],
    "With youth in foster care" => [ "Foster Care/Adoption" ],
    "work life balance, stress/anxiety" => [ "Self-Care/Personal Growth", "Mental Health" ],
    "Working with families to prevent their children entering DCF care, help stabilize kids in " \
      "foster/kinship placements, and with families reunifying with their children." => [ "Foster Care/Adoption" ],
    "Workplace (Workshops with Staff)" => [ "Staff/Organizational Development" ],
    "Youth who have been through trauma, re-entry youth, foster children, and sexually abused youth and children" =>
      [ "Foster Care/Adoption", "Child Abuse/Neglect", "Incarceration" ],
    "at meetings/convenings with partners in prevention" => [ "Staff/Organizational Development" ],
    "coaching support services" => [ "Self-Care/Personal Growth" ],
    "Family Resource Centers" => [ "Community Building" ]
  }.freeze

  # The same reads, where the term says which ages someone serves.
  PROPOSED_AGE_GROUPS = {
    "1:1 children and youth who experience domestic violence, dating violence, or sexual abuse" => %w[Children Teens],
    "Children, Adults and Families" => %w[Children Teens Adults Elders],
    "Children and Families" => %w[Children Teens Adults Elders],
    "Children's Advocacy Center Children & Families" => %w[Children],
    "Children, Emotional Regulation and structure for leaders" => %w[Children],
    "College campus" => %w[Adults],
    "Critically ill children" => %w[Children],
    "Culturally Specific Youth Program" => %w[Children Teens],
    "Day Program for adults with developmental and intellectual disabilities" => %w[Adults],
    "Department of Social Services/Children's Services" => %w[Children],
    "High level secondary art students" => %w[Teens],
    "Supervised visitation sessions for foster youth with their biological parents" => %w[Children Teens],
    "We are a Native American culturally specific dual sexual assault and domestic violence agency that " \
      "has programming for teens and adults, including elderly" => %w[Teens Adults Elders],
    "With youth in foster care" => %w[Children Teens],
    "youth services" => %w[Children Teens],
    "Youth who have been through trauma, re-entry youth, foster children, and sexually abused youth and children" =>
      %w[Children Teens]
  }.freeze

  # Free text that names no tag at all — a venue, a delivery method, or a shrug. Proposed
  # rather than decided, since "it means nothing" is a judgment too.
  PROPOSED_IGNORED = [
    "Art Events", "Community based services as well", "Community Leaders and Workshop in the community.",
    "Community library program", "Community spaces",
    "Community workshops at an art-based non-profit as well collaborative partners",
    "Gardens, parks, forests, beaches, outsise",
    "Group facilitation at partner agencies", "In presentations for the community", "Libraries",
    "Participants and recipients of social services.", "trainings in the community",
    "Workshop / retail shop setting"
  ].freeze

  def self.call(...)
    new(...).call
  end

  def initialize(quiet: false)
    @quiet = quiet
    @created = 0
    @pruned = 0
    @missing = []
    @proposed_ids = []
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
    record_sectors(PROPOSED_SECTORS, "filemaker", proposed: true)
    record_age_groups(PROPOSED_AGE_GROUPS, "filemaker", proposed: true)
    record_ignored(PROPOSED_IGNORED, "filemaker", proposed: true)
    prune_stale_proposals
    report
    self
  end

  private

  def record_sectors(table, source, proposed: false)
    table.each do |term, names|
      Array(names).each { |name| record(term, "Sector", sector_ids[name.downcase], source, name, proposed:) }
    end
  end

  # Resolved against every sector, published or not: the point of the table is the ones that
  # aren't, which the published lookup would report as missing.
  def record_retired_sectors(table, source)
    table.each { |term, name| record(term, "Sector", every_sector_id[name.downcase], source, name) }
  end

  def record_age_groups(table, source, proposed: false)
    table.each do |term, names|
      names.each { |name| record(term, "Category", age_group_ids[name.downcase], source, name, proposed:) }
    end
  end

  def record_ignored(terms, source, proposed: false)
    terms.each do |term|
      alias_row = TagAlias.find_or_initialize_by(name: term.squish, aliasable_type: nil, aliasable_id: nil)
      if alias_row.new_record?
        alias_row.update!(source: source, ignored: true, proposed: proposed)
        @created += 1
      end
      @proposed_ids << alias_row.id if proposed
    end
  end

  def record(term, type, id, source, name, proposed: false)
    unless id
      @missing << name
      @proposal_unmatched ||= proposed
      return
    end

    alias_row = TagAlias.find_or_initialize_by(name: term.squish, aliasable_type: type, aliasable_id: id)
    if alias_row.new_record?
      alias_row.update!(source: source, proposed: proposed)
      @created += 1
    end
    @proposed_ids << alias_row.id if proposed
  end

  # A proposed row is the seeder's own unreviewed guess, so one the tables no longer name is
  # withdrawn. Staff-validated rows are decided and kept. Skipped while a proposal's tag is
  # missing, since that proposal couldn't be matched this run.
  def prune_stale_proposals
    return if @proposal_unmatched

    @pruned = TagAlias.proposed.where.not(id: @proposed_ids).destroy_all.size
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

    puts "  #{@created} tag aliases added, #{@pruned} stale proposals withdrawn (#{TagAlias.count} recorded, #{TagAlias.proposed.count} awaiting staff validation)"
    puts "  no published tag named: #{@missing.uniq.sort.join(', ')} — seed the sectors and age ranges first" if @missing.any?
  end
end
