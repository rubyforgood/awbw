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

  describe "submitting a per-item credit preference" do
    let(:windows_type) { create(:windows_type) }
    let(:workshop) { create(:workshop) }
    let(:organization) { create(:organization) }

    SUBMISSIONS = {
      "story idea" => {
        path: :story_ideas_path, param_key: :story_idea, model: StoryIdea,
        attributes: ->(spec) {
          { title: "A story", rhino_body: "<p>Body</p>", permission_given: true,
            windows_type_id: spec.windows_type.id, workshop_id: spec.workshop.id, organization_id: spec.organization.id }
        }
      },
      "workshop variation idea" => {
        path: :workshop_variation_ideas_path, param_key: :workshop_variation_idea, model: WorkshopVariationIdea,
        attributes: ->(spec) {
          { name: "A variation", rhino_body: "<p>Body</p>", permission_given: true,
            windows_type_id: spec.windows_type.id, workshop_id: spec.workshop.id, organization_id: spec.organization.id }
        }
      },
      "workshop idea" => {
        path: :workshop_ideas_path, param_key: :workshop_idea, model: WorkshopIdea,
        attributes: ->(spec) { { title: "An idea", windows_type_id: spec.windows_type.id } }
      }
    }.freeze

    def submit(config, **overrides)
      attributes = config[:attributes].call(self).merge(overrides)
      post public_send(config[:path]), params: { config[:param_key] => attributes }
    end

    SUBMISSIONS.each do |label, config|
      it "ignores a non-admin's #{label} preference" do
        sign_in create(:user, :with_person)

        expect { submit(config, author_credit_preference: "anonymous") }.to change(config[:model], :count).by(1)
        expect(config[:model].last.author_credit_preference).not_to eq("anonymous")
      end

      it "stores an admin's #{label} preference" do
        sign_in create(:user, :admin, :with_person)

        submit(config, author_credit_preference: "anonymous")

        expect(config[:model].last.author_credit_preference).to eq("anonymous")
      end
    end

    it "ignores a non-admin's second-author preference on a story idea" do
      sign_in create(:user, :with_person)

      submit(SUBMISSIONS["story idea"], co_author_credit_preference: "anonymous")

      expect(StoryIdea.last.co_author_credit_preference).to be_nil
    end
  end

  it "names the generic credit when the account has no person" do
    sign_in create(:user)

    get new_story_idea_path

    expect(response.body.squish)
      .to include("credited as <strong>#{AuthorCreditable::FACILITATOR_AUTHOR_LABEL}</strong> until an admin links this account")
  end
end
