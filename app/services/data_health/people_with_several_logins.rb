module DataHealth
  # People carrying more than one login, usually left behind by a merge. The profile
  # warns one person at a time; the users deduper settles which login stays.
  class PeopleWithSeveralLogins < Check
    def title = "People with more than one login"

    def explanation
      "A merge can leave several logins on one person. Only one shows on their profile, so the " \
      "others can still sign in as a stranger to that profile."
    end

    def scope
      shared = User.where.not(person_id: nil).group(:person_id).having("COUNT(*) > 1").select(:person_id)
      Person.where(id: shared)
    end

    def describe(person)
      "#{person.name} — #{User.where(person_id: person.id).count} logins"
    end

    def path_for(person) = person_path(person)

    def review_path = dedupe_index_users_path

    def review_label = "Dedupe users"
  end
end
