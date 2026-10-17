module DataHealth
  # Counts for review pages that already exist elsewhere — possible duplicates and
  # author credit — so Data health shows how much is waiting on each. Their finders
  # load records in Ruby, so the page fetches these in a lazy frame.
  class Worklists
    include Rails.application.routes.url_helpers

    Entry = Data.define(:label, :count, :unit, :path)
    Section = Data.define(:title, :explanation, :entries) do
      def total = entries.sum(&:count)
    end

    def sections
      [
        Section.new("Possible duplicates",
                    "Records that look like the same person, organization, or thing. Merging is a judgment " \
                    "call, made on each dedupe page.",
                    duplicates),
        Section.new("Author credit to review",
                    "Content whose author credit doesn't resolve cleanly through a profile.",
                    author_credit)
      ]
    end

    def duplicates
      [
        Entry.new("People", PersonServices::DuplicateFinder.new.groups.size, "group", dedupe_index_people_path),
        Entry.new("Organizations", OrganizationServices::DuplicateFinder.new.groups.size, "group", dedupe_index_organizations_path),
        Entry.new("Workshops", WorkshopServices::DuplicateFinder.new.groups.size, "group", dedupe_index_workshops_path),
        Entry.new("Event registrations", EventRegistrationServices::DuplicateFinder.new.groups.size, "group", dedupe_index_event_registrations_path),
        Entry.new("Categories", Dedupable.name_groups(Category).size, "group", dedupe_index_categories_path),
        Entry.new("Sectors", Dedupable.name_groups(Sector).size, "group", dedupe_index_sectors_path)
      ]
    end

    def author_credit
      result = AuthorCreditDivergenceQuery.new.call
      [
        Entry.new("Preference drift", result.preference.size, "person", author_credit_divergence_section_path("preference")),
        Entry.new("Legacy name", result.legacy.sum { |group| group.entries.size }, "record", author_credit_divergence_section_path("legacy")),
        Entry.new("Creator fallback", result.creator.size, "person", author_credit_divergence_section_path("creator")),
        Entry.new("No author", result.unattributed.size, "record", author_credit_divergence_section_path("unattributed"))
      ]
    end

    private

    def author_credit_divergence_section_path(section)
      author_credit_divergences_path(section: section, anchor: "section-#{section}")
    end
  end
end
