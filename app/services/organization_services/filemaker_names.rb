module OrganizationServices
  # The names FileMaker gives the organizations and projects behind an organization's codes, to
  # tell which of several organizations carrying a code is the one FileMaker means: the one
  # whose name answers to some code it carries. Case, punctuation, a legal suffix and the
  # "(code)" a namesake takes don't count, and a single program may go by its organization's
  # name — so an organization merged from several keeps answering to every code it gathered.
  class FilemakerNames
    include FilemakerValues

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
      portal = bare_name(organization.name, codes)
      codes.flat_map { |code| names_for(code) }.compact_blank.any? do |name|
        name = bare_name(name, codes)
        DuplicateFinder.normalized_name(name) == DuplicateFinder.normalized_name(portal) ||
          DuplicateFinder.suffixless_name(name) == DuplicateFinder.suffixless_name(portal)
      end
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

    def bare_name(name, codes)
      codes.reduce(name.to_s) { |bare, code| bare.delete_suffix(" (#{code})") }
    end
  end
end
