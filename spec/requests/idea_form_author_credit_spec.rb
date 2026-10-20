require "rails_helper"

# A non-admin's credit choice on an idea form is their profile setting, so it governs
# every credit they carry. Admins get the per-item field instead.
RSpec.describe "Idea form author credit", type: :request do
  let(:workshop) { create(:workshop) }
  let(:organization) { create(:organization) }
  let(:windows_type) { create(:windows_type) }

  FORMS = {
    "story idea" => {
      new_path: :new_story_idea_path, create_path: :story_ideas_path, param_key: :story_idea, model: StoryIdea,
      attributes: ->(spec) {
        { title: "A story", rhino_body: "<p>Body</p>", permission_given: true,
          windows_type_id: spec.windows_type.id, workshop_id: spec.workshop.id, organization_id: spec.organization.id }
      }
    },
    "workshop variation idea" => {
      new_path: :new_workshop_variation_idea_path, create_path: :workshop_variation_ideas_path,
      param_key: :workshop_variation_idea, model: WorkshopVariationIdea,
      attributes: ->(spec) {
        { name: "A variation", rhino_body: "<p>Body</p>", permission_given: true,
          windows_type_id: spec.windows_type.id, workshop_id: spec.workshop.id, organization_id: spec.organization.id }
      }
    }
  }.freeze

  FORMS.each do |label, config|
    describe "the #{label} form" do
      let(:submitter) { create(:user, :with_person) }
      let(:person) { submitter.person }

      def submit(config, preference)
        attributes = config[:attributes].call(self).merge(author_credit_preference: preference)
        post public_send(config[:create_path]), params: { config[:param_key] => attributes }
      end

      context "as a non-admin" do
        before { sign_in submitter }

        it "offers the profile setting, preselected and with no per-item default" do
          person.update!(display_name_preference: "first_name_only")

          get public_send(config[:new_path])

          page = Capybara.string(response.body)
          select = page.find("select[name='#{config[:param_key]}[author_credit_preference]']")
          expect(select.find("option[selected]").value).to eq("first_name_only")
          expect(response.body).not_to include("Use my profile setting")
          expect(response.body).not_to include("None (follow profile)")
          expect(response.body).to include("Saved to your profile")
        end

        it "preselects \"Don't credit me by name\" when the profile contributes anonymously" do
          person.update!(anonymous_contributions: true)

          get public_send(config[:new_path])

          page = Capybara.string(response.body)
          select = page.find("select[name='#{config[:param_key]}[author_credit_preference]']")
          expect(select.find("option[selected]").value).to eq("anonymous")
        end

        it "turns on anonymous contributions for the whole profile" do
          submit(config, "anonymous")

          expect(person.reload.anonymous_contributions).to be(true)
          expect(config[:model].last.author_credit_preference).to eq("anonymous")
        end

        it "sets the profile's name format and clears anonymous contributions" do
          person.update!(anonymous_contributions: true)

          submit(config, "first_name_last_initial")

          person.reload
          expect(person.display_name_preference).to eq("first_name_last_initial")
          expect(person.anonymous_contributions).to be(false)
        end
      end

      context "as an admin" do
        let(:admin) { create(:user, :admin, :with_person) }

        before { sign_in admin }

        it "shows the per-item credit field" do
          get public_send(config[:new_path])

          expect(response.body).to include("None (follow profile)")
          expect(response.body).not_to include("Saved to your profile")
        end

        it "leaves the admin's own profile alone" do
          expect { submit(config, "anonymous") }
            .not_to(change { admin.person.reload.anonymous_contributions })
          expect(config[:model].last.author_credit_preference).to eq("anonymous")
        end
      end
    end
  end

  it "names the generic credit when the account has no person" do
    sign_in create(:user)

    get new_story_idea_path

    expect(response.body).to include(AuthorCreditable::FACILITATOR_AUTHOR_LABEL)
    expect(response.body).not_to include("How should we credit you?")
  end
end
