require "rails_helper"

# The idea forms are the only submission path a non-admin reaches, so they're the only
# place a submitter learns how they'll be credited. They state the profile's current
# answer rather than asking — the choice belongs on the profile, not per submission.
RSpec.describe "Idea form author credit notice", type: :request do
  # WorkshopIdeaPolicy#new? is admin-only for now ("temp block until stakeholders are
  # ready"), so that form is driven by an admin until it opens up.
  FORMS = {
    "story idea" => { path: :new_story_idea_path, admin_only: false },
    "workshop variation idea" => { path: :new_workshop_variation_idea_path, admin_only: false },
    "workshop idea" => { path: :new_workshop_idea_path, admin_only: true }
  }.freeze

  FORMS.each do |label, config|
    describe "the new #{label} form" do
      let(:submitter) do
        config[:admin_only] ? create(:user, :admin, :with_person) : create(:user, :with_person)
      end
      let(:person) { submitter.person }

      before { sign_in submitter }

      it "states how the submitter will be credited, formatted by their profile" do
        person.update!(display_name_preference: "first_name_last_initial")

        get public_send(config[:path])

        expect(response.body).to include("credited as")
        expect(response.body).to include("#{person.first_name} #{person.last_name.first}.")
      end

      it "names the generic credit when the profile suppresses credits" do
        person.update!(anonymous_contributions: true)

        get public_send(config[:path])

        expect(response.body).to include("AWBW Facilitator")
        expect(response.body).not_to include("credited as <strong>#{person.full_name}</strong>")
      end

      it "points at contact us instead of asking the submitter to choose" do
        get public_send(config[:path])

        expect(response.body).to include(contact_us_path)
        expect(response.body).not_to include("author_credit_preference")
      end
    end
  end
end
