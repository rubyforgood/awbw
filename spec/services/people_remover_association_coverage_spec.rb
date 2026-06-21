require "rails_helper"

# Drift guard: PeopleRemover hardcodes the person/user deletion graph, so adding
# an association to Person or User can silently leave a purge orphaning or
# blocking on the new data. This fails when a new association appears that isn't
# in the allowlist below — forcing a conscious decision to wire it into
# app/services/people_remover.rb (cascade it, tear it down explicitly, or make it
# a deliberate blocker) and then list it here.
RSpec.describe "PeopleRemover association coverage" do
  # Every association currently accounted for. Keep alphabetized.
  let(:person_associations) do
    %w[
      addresses affiliations avatar_attachment avatar_blob bookmarks categories
      categorizable_items comments communal_reports contact_methods created_by
      event_registrations event_staffs events form_submissions grants organizations
      pay_charges pay_customers pay_subscriptions payment_processor scholarships
      sectorable_items sectors staffed_events stories_as_spotlighted_facilitator
      updated_by user windows_types
    ]
  end

  let(:user_associations) do
    %w[
      bookmarked_events bookmarked_resources bookmarked_video_recordings
      bookmarked_workshops bookmarks comments created_by event_registrations events
      favorite_event notifications organizations person reports resources
      stories_as_creator story_ideas_as_creator updated_by user_form_form_fields
      user_forms windows_types workshop_ideas_as_creator workshop_logs
      workshop_variation_ideas_creator workshop_variations_as_creator workshops
    ]
  end

  it "accounts for every Person association" do
    unhandled = Person.reflect_on_all_associations.map { |a| a.name.to_s } - person_associations

    expect(unhandled).to be_empty,
      "New Person association(s) not accounted for: #{unhandled.join(', ')}.\n" \
      "Wire them into app/services/people_remover.rb (cascade, explicit teardown, " \
      "or a deliberate blocker), then add them to this allowlist."
  end

  it "accounts for every User association" do
    unhandled = User.reflect_on_all_associations.map { |a| a.name.to_s } - user_associations

    expect(unhandled).to be_empty,
      "New User association(s) not accounted for: #{unhandled.join(', ')}.\n" \
      "Wire them into app/services/people_remover.rb (cascade, explicit teardown, " \
      "or a deliberate blocker), then add them to this allowlist."
  end
end
