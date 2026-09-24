# The authored records a person is credited on, as both the combined feed
# (PersonCommentAggregator) and the "Log it against" picker
# (PeopleHelper#person_record_targets) count them — so a note filed against one
# always shows in the feed. Most follow full author-credit semantics (explicit
# author, else the creating account's person, via AuthorCreditable#credited_to_person);
# story ideas alone name no author, so only the creating account's person counts.
# The differing scopes are named here once so the two call sites can't drift.
module PersonCreditedRecords
  module_function

  def stories(person)
    Story.credited_to_person(person)
  end

  def story_ideas(person)
    StoryIdea.created_by_person(person&.id)
  end

  # Base Report is not author-credited; only MonthlyReport carries an author, and
  # STI stores its comments/notifications under commentable_type "Report".
  def monthly_reports(person)
    MonthlyReport.credited_to_person(person)
  end

  def workshop_ideas(person)
    WorkshopIdea.credited_to_person(person)
  end

  def workshop_logs(person)
    WorkshopLog.credited_to_person(person)
  end

  def workshop_variations(person)
    WorkshopVariation.credited_to_person(person)
  end

  def workshop_variation_ideas(person)
    WorkshopVariationIdea.credited_to_person(person)
  end
end
