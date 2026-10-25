module DataHealth
  # FileMaker archive rows whose code no portal record carries — what never came over.
  # An FM organization also counts as imported when a portal org carries one of its
  # projects' codes, as the archive page links it (FmArchivesController).
  class FilemakerNotImported
    PER_PAGE = 25

    Kind = Data.define(:key, :label, :archive, :portal, :explanation)

    KINDS = [
      Kind.new("organizations", "Organizations", FmOrganization, Organization,
               "FileMaker organizations no portal organization carries the code of, directly or through one of its projects."),
      Kind.new("programs", "Programs", FmProject, Organization,
               "FileMaker projects (one art program at an organization) no portal organization carries the code of."),
      Kind.new("people", "People", FmRolodex, Person,
               "Rolodex cards no portal person carries the code of. The people import skips agency, deleted and nameless cards."),
      Kind.new("personnel", "Personnel", FmPersonnel, Affiliation,
               "FileMaker personnel rows (a person on a project, with their role) no portal affiliation carries the code of."),
      Kind.new("jobs", "Job affiliations", FmPeopleToOrganization, Affiliation,
               "FileMaker people-to-organization rows (a person's job title at an organization) no portal affiliation carries the code of.")
    ].freeze

    def self.kind(key) = KINDS.find { |kind| kind.key == key } || KINDS.first

    def kinds = KINDS

    def count(kind) = missing_ids(kind).size

    def page(kind, number)
      ids = missing_ids(kind)
      WillPaginate::Collection.create(number, PER_PAGE, ids.size) do |pager|
        slice = ids.slice(pager.offset, pager.per_page) || []
        rows = kind.archive.where(fm_id: slice).index_by(&:fm_id)
        pager.replace(rows.values_at(*slice).compact)
      end
    end

    private

    # Shorter ids first, so unpadded numbers and widening prefixes (PS0028 … PS10667) read in order.
    def missing_ids(kind)
      @missing_ids ||= {}
      @missing_ids[kind.key] ||= begin
        imported = imported_codes(kind)
        kind.archive.pluck(:fm_id).reject { |id| imported.include?(id) }.sort_by { |id| [ id.length, id ] }
      end
    end

    def imported_codes(kind)
      codes = portal_codes(kind.portal)
      return codes unless kind.archive == FmOrganization

      codes | FmProject.where(fm_id: codes.to_a).pluck(Arel.sql("data->>'$.OrgID'")).compact
    end

    def portal_codes(model)
      @portal_codes ||= {}
      @portal_codes[model] ||= model.where.not(filemaker_code: [ nil, "" ]).pluck(:filemaker_code)
                                    .flat_map { |value| model.split_filemaker_codes(value) }.to_set
    end
  end
end
