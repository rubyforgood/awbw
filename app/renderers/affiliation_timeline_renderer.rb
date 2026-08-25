class AffiliationTimelineRenderer < ApplicationTimelineRenderer
  private

  # Link to the *other* side of the affiliation. This link is on
  # owner's timeline/page, so the useful destination is the affiliated record.
  def path_for(affiliation)
    if @owner.is_a?(Organization)
      routes.person_path(affiliation.person)
    else
      routes.organization_path(affiliation.organization)
    end
  end
end
