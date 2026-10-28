module OrganizationServices
  # The names FileMaker gives the organizations and projects behind an organization's codes, to
  # tell which of several organizations carrying a code is the one FileMaker means: the one
  # whose name answers to some code it carries. Case, punctuation, a legal suffix, a trailing
  # audience word (the old app's "Women's", "Children's", "Combined"), the "(code)" a namesake
  # takes, and extra words on either side don't count, and a single program may go by its
  # organization's name — so an organization merged from several keeps answering to every
  # code it gathered. A code in SAME_PLACE_CODES answers whatever the name.
  class FilemakerNames
    include FilemakerValues

    AUDIENCE_WORDS = (DuplicateFinder::AUDIENCE_WORDS + %w[womens women mens men teens teen youth]).freeze
    FILLER_WORDS = %w[the of and].freeze
    # The old app's audience versions of one program. Women, Men and Youth also end real names
    # ("Safe Place for Youth"), so only their possessives mark a version.
    VERSION_WORDS = (DuplicateFinder::AUDIENCE_WORDS + %w[womens mens]).freeze
    TRAILING_AUDIENCE = /[\s,–—-]*\b(?:combined|children[’'í]?s|children|adults?|women[’'í]?s|men[’'í]?s)\s*\z/i
    TRAILING_CODE = /\s*\((?:ORG|P)\d+\)\z/

    # "ís" is how a mis-encoded "’s" reached some names ("Womenís").
    def self.words(name, audience: AUDIENCE_WORDS)
      words = DuplicateFinder.suffixless_name(name.to_s.gsub("&", " and ").gsub(/í(?=s\b)/, "")).split
      words.pop while words.size > 1 && audience.include?(words.last)
      words
    end

    # What one place's names share, whichever audience version or "(code)" a name carries.
    def self.same_name_key(name)
      words(name.to_s.sub(TRAILING_CODE, ""), audience: VERSION_WORDS).join(" ")
    end

    def self.without_audience(name)
      name = name.to_s.squish
      loop do
        shorter = name.sub(TRAILING_AUDIENCE, "")
        return name if shorter == name || shorter.blank?

        name = shorter
      end
    end

    def initialize(projects: FmProject.all.to_a)
      @projects = projects.index_by(&:fm_id)
      @projects_by_organization = projects.group_by { |project| project.data["OrgID"].to_s }
      @organization_names = FmOrganization.all.to_h { |fm_organization| [ fm_organization.fm_id, organization_name(fm_organization) ] }
    end

    def pick(organizations)
      organizations.find { |organization| answers?(organization) } || organizations.first
    end

    def answers?(organization)
      codes = organization.filemaker_codes
      return true if codes.any? { |code| same_place_code?(code) }

      portal = bare_name(organization.name, codes)
      codes.flat_map { |code| names_for(code) }.compact_blank.any? { |name| same_place?(portal, bare_name(name, codes)) }
    end

    def organization_name(fm_organization)
      name = clip(fm_organization.data["OrgName"].to_s.squish)
      return name unless RETIRED_RENAMED.include?(fm_organization.fm_id)

      clip("#{name.gsub(RETIRED_MARKER, "").squish} (#{fm_organization.fm_id})")
    end

    def project_name(project)
      clip(project.data["ProjectName"].to_s.squish)
    end

    private

    def names_for(code)
      project = @projects[code]
      return [ project_name(project), @organization_names[project.data["OrgID"].to_s] ] if project

      [ @organization_names[code], *@projects_by_organization.fetch(code, []).map { |program| project_name(program) } ]
    end

    # The same words, or every telling word of one name — at least two — within the other
    # ("Harbor House - Outreach" is Harbor House, Inc.; "Harbor Shelter" is Harbor Shelter South).
    def same_place?(portal, name)
      ours = words(portal)
      theirs = words(name)
      return true if ours == theirs

      fewer, more = [ ours, theirs ].map { |list| list.to_set - FILLER_WORDS }.sort_by(&:size)
      fewer.size >= 2 && fewer <= more
    end

    def words(name) = self.class.words(name)

    def bare_name(name, codes)
      codes.reduce(name.to_s) { |bare, code| bare.delete_suffix(" (#{code})") }
    end
  end
end
