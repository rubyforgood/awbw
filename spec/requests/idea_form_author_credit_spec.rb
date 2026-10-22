require "rails_helper"

# The profile decides how a submitter is credited, so the idea forms only tell a
# non-admin what that is. The deprecated per-item field is admin-only.
RSpec.describe "Idea form author credit", type: :request do
  FORMS = {
    "story idea" => { path: :new_story_idea_path, param_key: :story_idea },
    "workshop variation idea" => { path: :new_workshop_variation_idea_path, param_key: :workshop_variation_idea }
  }.freeze

  FORMS.each do |label, config|
    describe "the new #{label} form" do
      let(:field_name) { "#{config[:param_key]}[author_credit_preference]" }

      context "as a non-admin" do
        let(:submitter) { create(:user, :with_person) }
        let(:person) { submitter.person }

        before { sign_in submitter }

        it "hides the per-item credit field" do
          get public_send(config[:path])

          expect(Capybara.string(response.body)).not_to have_select(field_name)
        end

        it "states how the submitter will be credited, formatted by their profile" do
          person.update!(display_name_preference: "first_name_last_initial")

          get public_send(config[:path])

          credit = ERB::Util.h("#{person.first_name} #{person.last_name.first}.")
          expect(response.body.squish).to include("credited as <strong>#{credit}</strong>, from your profile")
        end

        it "names the generic credit when the profile suppresses credits" do
          person.update!(anonymous_contributions: true)

          get public_send(config[:path])

          expect(response.body.squish)
            .to include("credited as <strong>#{AuthorCreditable::FACILITATOR_AUTHOR_LABEL}</strong>, from your profile")
        end
      end

      context "as an admin" do
        before { sign_in create(:user, :admin, :with_person) }

        it "shows the per-item credit field, marked deprecated" do
          get public_send(config[:path])

          expect(Capybara.string(response.body)).to have_select(field_name)
          expect(response.body).to include("Deprecated")
        end
      end
    end
  end

  it "names the generic credit when the account has no person" do
    sign_in create(:user)

    get new_story_idea_path

    expect(response.body.squish)
      .to include("credited as <strong>#{AuthorCreditable::FACILITATOR_AUTHOR_LABEL}</strong> until an admin links this account")
  end
end
