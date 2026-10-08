require "rails_helper"

RSpec.describe "/stories", type: :request do
  let(:admin)        { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  let(:windows_type) { create(:windows_type) }
  let(:workshop)     { create(:workshop) }
  let(:organization) { create(:organization) }

  let(:base_attributes) do
    {
      title: "Story #{SecureRandom.hex(4)}",
      rhino_body: "<p>Once upon a time...</p>",
      windows_type_id: windows_type.id,
      workshop_id: workshop.id,
      organization_id: organization.id,
      created_by_id: admin.id,
      updated_by_id: admin.id
    }
  end

  let!(:published_story) do
    Story.create!(base_attributes.merge(
      title: "Story #{SecureRandom.hex(4)}",
      published: true
    ))
  end

  let!(:public_story) do
    create(:story, :published, :publicly_visible)
  end

  let!(:private_story) do
    Story.create!(base_attributes.merge(
      title: "Story #{SecureRandom.hex(4)}",
      published: false,
      publicly_visible: false
    ))
  end

  # Published AND publicly visible, but funder-only — so it must still stay out
  # of every general-audience listing despite the public flags.
  let!(:funder_only_story) do
    create(:story, :published, :publicly_visible, :funder_only, title: "Funder Only #{SecureRandom.hex(4)}")
  end

  # ==========================================================
  # ADMIN
  # ==========================================================
  describe "as admin" do
    before { sign_in admin }

    describe "GET /index" do
      it "returns all stories" do
        get stories_url, params: {}, headers: { "Turbo-Frame" => "stories_results" }
        expect(response.body).to include(published_story.title)
        expect(response.body).to include(public_story.title)
        expect(response.body).to include(private_story.title)
      end

      it "shows funder-only stories to admins, flagged with a chip" do
        get stories_url, params: {}, headers: { "Turbo-Frame" => "stories_results" }
        expect(response.body).to include(funder_only_story.title)
        expect(response.body).to include("Funder-only")
      end

      it "narrows to funder-only stories when the funder_only filter is set" do
        get stories_url(funder_only: "true"), headers: { "Turbo-Frame" => "stories_results" }
        expect(response.body).to include(funder_only_story.title)
        expect(response.body).not_to include(published_story.title)
      end

      it "filters by organization_id on lazy turbo-frame request" do
        other_org = create(:organization)
        story_in_other_org = Story.create!(base_attributes.merge(
          title: "Other Org Story #{SecureRandom.hex(4)}",
          organization_id: other_org.id,
          published: true
        ))

        get stories_url(organization_id: organization.id), headers: { "Turbo-Frame" => "stories_results" }
        expect(response.body).to include(published_story.title)
        expect(response.body).not_to include(story_in_other_org.title)
      end

      it "shows the empty-state message when no stories match" do
        get stories_url(title: "no-such-story-zzz"), headers: { "Turbo-Frame" => "stories_results" }
        expect(response.body).to include("No stories found")
      end

      it "filters by title and body query together" do
        match = Story.create!(base_attributes.merge(title: "Best Story Match", rhino_body: "healing through art", published: true))
        title_only = Story.create!(base_attributes.merge(title: "Best Story Other", rhino_body: "something else", published: true))
        body_only = Story.create!(base_attributes.merge(title: "Unrelated Tale", rhino_body: "healing through art", published: true))

        get stories_url(title: "Best Story", query: "healing"), headers: { "Turbo-Frame" => "stories_results" }

        expect(response.body).to include(match.title)
        expect(response.body).not_to include(title_only.title)
        expect(response.body).not_to include(body_only.title)
      end

      describe "external link handling" do
        let(:turbo_headers) { { "Turbo-Frame" => "stories_results" } }

        let!(:external_story) do
          create(:story, :published, title: "External Story", website_url: "https://example.com/article")
        end

        let!(:internal_story) do
          create(:story, :published, title: "Internal Story", website_url: nil)
        end

        it "View button links to external URL for stories with website_url" do
          get stories_url, params: {}, headers: turbo_headers
          expect(response.body).to include('href="https://example.com/article"')
        end

        it "View button links to show page for stories without website_url" do
          get stories_url, params: {}, headers: turbo_headers
          expect(response.body).to include(%(href="#{story_path(internal_story)}"))
        end

        it "shows admin-only Details button for stories with external URL" do
          get stories_url, params: {}, headers: turbo_headers
          expect(response.body).to include(%(href="#{story_path(external_story, no_redirect: true)}"))
          expect(response.body).to include("Details")
        end

        it "does not show Details button for stories without external URL" do
          get stories_url, params: {}, headers: turbo_headers
          expect(response.body).not_to include(%(href="#{story_path(internal_story, no_redirect: true)}"))
        end
      end

      describe "sorting" do
        let(:turbo_headers) { { "Turbo-Frame" => "stories_results" } }

        let(:org_alpha) { create(:organization, name: "Alpha Org") }
        let(:org_zulu) { create(:organization, name: "Zulu Org") }
        let(:wt_adult) { create(:windows_type, short_name: "Adult") }
        let(:wt_children) { create(:windows_type, short_name: "Children") }
        let(:ws_art) { create(:workshop, title: "Art Workshop") }
        let(:ws_music) { create(:workshop, title: "Music Workshop") }

        let(:author_alice) do
          person = create(:person, first_name: "Alice", last_name: "Smith")
          person.user
        end
        let(:author_zara) do
          person = create(:person, first_name: "Zara", last_name: "Jones")
          person.user
        end

        let!(:story_a) do
          create(:story, :published,
            title: "Alpha Story",
            windows_type: wt_adult,
            workshop: ws_art,
            organization: org_alpha,
            created_by: author_alice).tap do |s|
            s.update_columns(created_at: 3.days.ago, updated_at: 1.day.ago)
          end
        end

        let!(:story_z) do
          create(:story, :published,
            title: "Zulu Story",
            windows_type: wt_children,
            workshop: ws_music,
            organization: org_zulu,
            created_by: author_zara).tap do |s|
            s.update_columns(created_at: 1.day.ago, updated_at: 3.days.ago)
          end
        end

        def titles_in_response
          response.body.scan(/(?:Alpha|Zulu) Story/)
        end

        it "defaults to created_at desc when no sort param" do
          get stories_url, params: {}, headers: turbo_headers
          expect(titles_in_response).to eq([ "Zulu Story", "Alpha Story" ])
        end

        it "sorts by title asc" do
          get stories_url, params: { sort: "title", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Alpha Story", "Zulu Story" ])
        end

        it "sorts by title desc" do
          get stories_url, params: { sort: "title", direction: "desc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Zulu Story", "Alpha Story" ])
        end

        it "sorts by updated_at asc" do
          get stories_url, params: { sort: "updated_at", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Zulu Story", "Alpha Story" ])
        end

        it "sorts by windows_type asc" do
          get stories_url, params: { sort: "windows_type", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Alpha Story", "Zulu Story" ])
        end

        it "sorts by workshop asc" do
          get stories_url, params: { sort: "workshop", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Alpha Story", "Zulu Story" ])
        end

        it "sorts by workshop using a link's typed-in title when it has no workshop" do
          [ story_a, story_z ].each { |story| story.story_workshops.destroy_all }
          story_a.update!(workshop: nil)
          story_z.update!(workshop: nil)
          story_a.story_workshops.create!(external_workshop_title: "Zeppelin Session")
          story_z.story_workshops.create!(external_workshop_title: "Aardvark Session")

          get stories_url, params: { sort: "workshop", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Zulu Story", "Alpha Story" ])
        end

        it "sorts by workshop using the legacy external title when there are no links" do
          [ story_a, story_z ].each { |story| story.story_workshops.destroy_all }
          story_a.update!(workshop: nil, external_workshop_title: "Zeppelin Session")
          story_z.update!(workshop: nil, external_workshop_title: "Aardvark Session")

          get stories_url, params: { sort: "workshop", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Zulu Story", "Alpha Story" ])
        end

        it "sorts by workshop for stories that only have the legacy workshop column" do
          [ story_a, story_z ].each { |story| story.story_workshops.destroy_all }

          get stories_url, params: { sort: "workshop", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Alpha Story", "Zulu Story" ])
        end

        it "sorts by author asc" do
          get stories_url, params: { sort: "author", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Alpha Story", "Zulu Story" ])
        end

        it "sorts by the credited author, not the creator, when they differ" do
          # Explicit authors invert the creators: story_a is created by Alice but
          # authored by Zeke; story_z is created by Zara but authored by Aaron.
          # The column shows the author, so the sort must key off it too — keying
          # off the creator would put Alpha before Zulu.
          story_a.update!(author: create(:person, first_name: "Zeke", last_name: "Zimmer"))
          story_z.update!(author: create(:person, first_name: "Aaron", last_name: "Adams"))

          get stories_url, params: { sort: "author", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Zulu Story", "Alpha Story" ])
        end

        it "sorts by organization asc" do
          get stories_url, params: { sort: "organization", direction: "asc" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Alpha Story", "Zulu Story" ])
        end

        it "falls back to created_at desc for invalid sort column" do
          get stories_url, params: { sort: "bogus" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Zulu Story", "Alpha Story" ])
        end

        it "combines sort with title filter" do
          get stories_url, params: { sort: "title", direction: "desc", title: "Story" }, headers: turbo_headers
          expect(titles_in_response).to eq([ "Zulu Story", "Alpha Story" ])
        end
      end
    end

    describe "GET /show" do
      it "can view any story" do
        get story_url(private_story)
        expect(response).to have_http_status(:ok)
      end
    end

    describe "GET /edit" do
      it "renders the hover definitions panel with copy for each flag" do
        get edit_story_url(private_story)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("group-hover:block")
        expect(response.body).to include(VisibilityFlagsHelper::FLAG_DEFINITIONS[:publicly_visible][:description])
      end
    end

    describe "POST /create" do
      it "creates a story" do
        expect {
          post stories_url, params: { story: base_attributes }
        }.to change(Story, :count).by(1)

        expect(response).to redirect_to(story_url(Story.last))
      end

      it "redirects with 303 See Other so Turbo advances past the form" do
        post stories_url, params: { story: base_attributes }
        expect(response).to have_http_status(:see_other)
      end

      it "records the current user as created_by regardless of submitted value" do
        someone_else = create(:user)
        post stories_url, params: { story: base_attributes.merge(created_by_id: someone_else.id) }

        expect(Story.last.created_by).to eq(admin)
      end

      it "assigns the chosen person as author" do
        facilitator = create(:person)
        post stories_url, params: { story: base_attributes.merge(author_id: facilitator.id) }

        expect(Story.last.author).to eq(facilitator)
      end

      it "assigns a second author alongside the first" do
        author = create(:person)
        co_author = create(:person)
        post stories_url, params: { story: base_attributes.merge(author_id: author.id, co_author_id: co_author.id) }

        story = Story.last
        expect(story.author).to eq(author)
        expect(story.co_author).to eq(co_author)
      end

      context "when promoting a story idea into a story" do
        let(:submitter) { create(:user, email: "submitter@example.com") }
        let(:story_idea) { create(:story_idea, created_by: submitter) }

        it "holds both promotion notices while the story is unpublished" do
          expect {
            post stories_url, params: { story: base_attributes.merge(story_idea_id: story_idea.id) }
          }.not_to change(Notification, :count)
        end

        it "notifies the idea's submitter and an admin when the story is created already published" do
          expect {
            post stories_url, params: { story: base_attributes.merge(story_idea_id: story_idea.id, published: "1") }
          }.to change(Notification, :count).by(2)

          person_note = Notification.find_by(kind: "story_promoted")
          expect(person_note.recipient_role).to eq("person")
          expect(person_note.recipient_email).to eq(submitter.email)
          expect(person_note.noticeable).to eq(Story.last)

          admin_note = Notification.find_by(kind: "story_promoted_fyi")
          expect(admin_note.recipient_role).to eq("admin")
          expect(admin_note.recipient_email).to eq(ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"))
        end

        it "pre-checks the funder-only box when promoting a funder-only idea" do
          funder_idea = create(:story_idea, :funder_only, created_by: submitter)
          get new_story_url(story_idea_id: funder_idea.id)

          checkbox = Nokogiri::HTML(response.body).at_css("input#story_funder_only[type='checkbox']")
          expect(checkbox["checked"]).to be_present
        end

        it "leaves the funder-only box unchecked when promoting a regular idea" do
          get new_story_url(story_idea_id: story_idea.id)

          checkbox = Nokogiri::HTML(response.body).at_css("input#story_funder_only[type='checkbox']")
          expect(checkbox["checked"]).to be_nil
        end
      end

      it "persists funder_only when the box is checked on submit" do
        post stories_url, params: { story: base_attributes.merge(funder_only: "1") }
        expect(Story.order(:created_at).last).to be_funder_only
      end

      it "does not send promotion emails when no story idea is linked" do
        expect {
          post stories_url, params: { story: base_attributes }
        }.not_to change(Notification, :count)
      end
    end

    describe "GET /new from a workshop page" do
      it "pre-selects the workshop passed in the workshop_id param" do
        workshop = create(:workshop, title: "Origin Workshop")

        get new_story_url(workshop_id: workshop.id)

        expect(response).to have_http_status(:ok)
        selected = Nokogiri::HTML(response.body)
          .at("select[name='story[story_workshops_attributes][0][workshop_id]'] option[selected]")
        expect(selected&.[]("value")).to eq(workshop.id.to_s)
      end

      it "offers a back link to the originating workshop" do
        workshop = create(:workshop)

        get new_story_url(workshop_id: workshop.id, return_to: "workshop")

        expect(response.body).to include(workshop_path(workshop, anchor: "workshopStories"))
      end

      it "keeps the back link after a rejected save" do
        workshop = create(:workshop)

        post stories_url, params: { return_to: "workshop", workshop_id: workshop.id,
                                    story: { title: "" } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include(workshop_path(workshop, anchor: "workshopStories"))
      end

      it "pre-selects the windows audience passed in the windows_type_id param" do
        workshop = create(:workshop)

        get new_story_url(workshop_id: workshop.id, windows_type_id: workshop.windows_type_id)

        expect(response).to have_http_status(:ok)
        selected = Nokogiri::HTML(response.body)
          .at("select[name='story[windows_type_id]'] option[selected]")
        expect(selected&.[]("value")).to eq(workshop.windows_type_id.to_s)
      end
    end

    describe "GET /new promoting from a story idea" do
      it "copies the idea's workshop and external title into the new story form" do
        workshop = create(:workshop, title: "Promoted Workshop")
        idea = create(:story_idea, workshop: workshop, external_workshop_title: "Unlisted Session")

        get new_story_url(story_idea_id: idea.id)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Promoted Workshop")
        expect(response.body).to include("Unlisted Session")
      end

      it "carries the idea's author, second author, and spotlighted facilitator into the new story form" do
        first = create(:person, first_name: "Ada", last_name: "Lovelace")
        second = create(:person, first_name: "Grace", last_name: "Hopper")
        spotlight = create(:person, first_name: "Katherine", last_name: "Johnson")
        idea = create(:story_idea, author: first, co_author: second,
                                   co_author_credit_preference: "first_name_only",
                                   spotlighted_facilitator: spotlight)

        get new_story_url(story_idea_id: idea.id)

        expect(response).to have_http_status(:ok)
        page = Capybara.string(response.body)
        expect(page).to have_select("story[author_id]", selected: first.remote_search_label[:label])
        expect(page).to have_select("story[co_author_id]", selected: second.remote_search_label[:label])
        expect(page).to have_select("story[spotlighted_facilitator_id]", selected: spotlight.remote_search_label[:label])
        expect(page).to have_select("story[co_author_credit_preference]", selected: "First name only")
      end
    end

    describe "legacy workshop on the edit page" do
      it "surfaces the legacy direct workshop read-only when present" do
        legacy_workshop = create(:workshop, title: "Legacy Direct Workshop")
        story = create(:story, :published, workshop: legacy_workshop)

        get edit_story_url(story)

        expect(response.body).to include("Previously linked (read-only)")
        expect(response.body).to include("Legacy Direct Workshop")
      end

      it "omits the read-only legacy block when there is no direct workshop data" do
        story = create(:story, :published, workshop: nil, external_workshop_title: nil)

        get edit_story_url(story)

        expect(response.body).not_to include("Previously linked (read-only)")
      end
    end

    describe "PATCH /update linked workshops" do
      let(:workshop) { create(:workshop, title: "Anger Volcano") }

      it "accepts removing a workshop row and re-adding the same workshop" do
        story = create(:story, :published, workshop: nil)
        existing = story.story_workshops.create!(workshop: workshop)

        patch story_url(story), params: { story: { story_workshops_attributes: {
          "0" => { id: existing.id, workshop_id: workshop.id, _destroy: "1" },
          "1" => { workshop_id: workshop.id, external_workshop_title: "Retyped" }
        } } }

        expect(response).to have_http_status(:see_other)
        row = story.reload.story_workshops.sole
        expect(row.workshop).to eq(workshop)
        expect(row.external_workshop_title).to eq("Retyped")
      end

      it "reports an error when a new story is created with the same workshop twice" do
        expect {
          post stories_url, params: { story: base_attributes.except(:workshop_id).merge(
            story_workshops_attributes: {
              "0" => { workshop_id: workshop.id },
              "1" => { workshop_id: workshop.id }
            }
          ) }
        }.not_to change(Story, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("is already linked to this story")
      end

      it "reports an error when the same workshop is added twice" do
        story = create(:story, :published, workshop: nil)

        patch story_url(story), params: { story: { story_workshops_attributes: {
          "0" => { workshop_id: workshop.id },
          "1" => { workshop_id: workshop.id }
        } } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("is already linked to this story")
        expect(story.reload.story_workshops).to be_empty
      end

      it "accepts the same workshop twice under different titles" do
        story = create(:story, :published, workshop: nil)

        patch story_url(story), params: { story: { story_workshops_attributes: {
          "0" => { workshop_id: workshop.id },
          "1" => { workshop_id: workshop.id, external_workshop_title: "Teen variant" }
        } } }

        expect(response).to have_http_status(:see_other)
        expect(story.reload.story_workshops.count).to eq(2)
      end
    end

    describe "PATCH /update publishing a promoted story" do
      let(:submitter) { create(:user, email: "submitter@example.com") }
      let(:story_idea) { create(:story_idea, created_by: submitter) }
      let(:promoted_story) { Story.create!(base_attributes.merge(story_idea: story_idea, published: false)) }

      def promotion_notices
        Notification.where(noticeable: promoted_story).pluck(:kind, :recipient_email)
      end

      it "notifies the idea's submitter and an admin when the story is published" do
        patch story_url(promoted_story), params: { story: { published: "1" } }

        expect(promotion_notices).to contain_exactly(
          [ "story_promoted", submitter.email ],
          [ "story_promoted_fyi", ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org") ]
        )
      end

      it "sends nothing while the story stays unpublished" do
        patch story_url(promoted_story), params: { story: { title: "Retitled" } }

        expect(promotion_notices).to be_empty
      end

      it "does not resend either notice when the story is unpublished and republished" do
        patch story_url(promoted_story), params: { story: { published: "1" } }
        patch story_url(promoted_story), params: { story: { published: "0" } }
        patch story_url(promoted_story), params: { story: { published: "1" } }

        expect(promotion_notices.size).to eq(2)
      end

      it "does not email anyone when publishing a story with no story idea" do
        expect {
          patch story_url(private_story), params: { story: { published: "1" } }
        }.not_to change(Notification, :count)
      end
    end

    describe "primary sector and category" do
      let(:health) { create(:sector, :published, name: "Healthcare") }
      let(:education) { create(:sector, :published, name: "Education") }
      let(:population) { create(:category_type, :published, name: CategoriesTaggable::STORY_POPULATION_CATEGORY_TYPE, story_specific: true) }
      let(:children) { create(:category, :published, name: "Children", category_type: population) }
      let(:teens) { create(:category, :published, name: "Teens", category_type: population) }

      it "marks the starred sector and category primary on create" do
        post stories_url, params: { story: base_attributes.merge(
          sector_ids: [ health.id, education.id ], primary_sector_id: education.id,
          category_ids: [ children.id, teens.id ], primary_category_id: teens.id
        ) }

        story = Story.order(:created_at).last
        expect(story.primary_sector).to eq(education)
        expect(story.sectorable_items.where(is_primary: true).count).to eq(1)
        expect(story.primary_category).to eq(teens)
        expect(story.categorizable_items.where(is_primary: true).count).to eq(1)
      end

      it "tags a starred sector and category even when their boxes are unchecked" do
        post stories_url, params: { story: base_attributes.merge(
          sector_ids: [ "" ], primary_sector_id: health.id,
          category_ids: [ "" ], primary_category_id: children.id
        ) }

        story = Story.order(:created_at).last
        expect(story.sectors).to contain_exactly(health)
        expect(story.primary_sector).to eq(health)
        expect(story.primary_category).to eq(children)
      end

      it "moves the primary on update and clears it when unstarred" do
        story = create(:story, :published)
        story.sectorable_items.create!(sector: health, is_primary: true)
        story.sectorable_items.create!(sector: education, is_primary: false)
        story.categorizable_items.create!(category: children, is_primary: true)

        patch story_url(story), params: { story: {
          sector_ids: [ health.id, education.id ], primary_sector_id: education.id,
          category_ids: [ children.id ], primary_category_id: ""
        } }

        expect(response).to have_http_status(:see_other)
        expect(story.reload.primary_sector).to eq(education)
        expect(story.sectorable_items.where(is_primary: true).count).to eq(1)
        expect(story.primary_category).to be_nil
        expect(story.categories).to contain_exactly(children)
      end

      it "marks a starred age range primary" do
        elders = create(:category, :published, name: "Elders", category_type: create(:category_type, :published, name: "AgeRange"))

        post stories_url, params: { story: base_attributes.merge(
          category_ids: [ elders.id ], primary_category_id: elders.id
        ) }

        expect(Story.order(:created_at).last.primary_category).to eq(elders)
      end

      it "ignores a primary category outside the audience types" do
        theme = create(:category, :published)

        post stories_url, params: { story: base_attributes.merge(
          category_ids: [ theme.id ], primary_category_id: theme.id
        ) }

        story = Story.order(:created_at).last
        expect(story.categories).to contain_exactly(theme)
        expect(story.primary_category).to be_nil
      end

      it "only offers the category star on the audience tag set" do
        children
        theme = create(:category, :published, category_type: create(:category_type, :published))

        get edit_story_url(create(:story, :published))

        page = Nokogiri::HTML(response.body)
        expect(page.at_css("input#story_primary_category_id_#{children.id}")).to be_present
        expect(page.at_css("input#story_category_ids_#{theme.id}")).to be_present
        expect(page.at_css("input#story_primary_category_id_#{theme.id}")).to be_nil
      end

      it "shows published age ranges, then published story populations, as one starrable tag set" do
        age_range = create(:category_type, :published, name: "AgeRange")
        elders = create(:category, :published, name: "Elders", category_type: age_range)
        create(:category, name: "Infants", category_type: age_range)
        self_category = create(:category, :published, name: "Self", category_type: population)
        create(:category, name: "Teens_", category_type: population)

        get edit_story_url(create(:story, :published))

        page = Nokogiri::HTML(response.body)
        grid = page.at_css("[data-controller='primary-tag']:has(#story_primary_category_id_#{elders.id})")
        rows = grid.css("> div").map { |row| row.css("span.text-sm").map { |label| label.text.strip } }
        expect(rows).to eq([ [ "Elders" ], [ "Self" ] ])
        expect(page.css("#story_category_ids_#{self_category.id}").size).to eq(1)
      end

      it "leaves existing primaries alone when the form doesn't send a primary" do
        story = create(:story, :published)
        story.sectorable_items.create!(sector: health, is_primary: true)

        patch story_url(story), params: { story: { sector_ids: [ health.id ] } }

        expect(story.reload.primary_sector).to eq(health)
      end

      it "shows the starred primary sector on the story page" do
        story = create(:story, :published)
        story.sectorable_items.create!(sector: health, is_primary: true)

        get story_url(story, no_redirect: true)

        expect(Capybara.string(response.body)).to have_css("a[title='Primary sector'] i.fa-star")
      end

      it "stars the current primaries on the edit form" do
        story = create(:story, :published)
        story.sectorable_items.create!(sector: health, is_primary: true)
        story.categorizable_items.create!(category: children, is_primary: true)

        get edit_story_url(story)

        page = Nokogiri::HTML(response.body)
        expect(page.at_css("input#story_primary_sector_id_#{health.id}")["checked"]).to be_present
        expect(page.at_css("input#story_primary_category_id_#{children.id}")["checked"]).to be_present
      end

      it "carries the story idea's primaries into the promotion form" do
        story_idea = create(:story_idea)
        story_idea.sectorable_items.create!(sector: health, is_primary: true)
        story_idea.categorizable_items.create!(category: children, is_primary: true)

        get new_story_url(story_idea_id: story_idea.id)

        page = Nokogiri::HTML(response.body)
        expect(page.at_css("input#story_primary_sector_id_#{health.id}")["checked"]).to be_present
        expect(page.at_css("input#story_primary_category_id_#{children.id}")["checked"]).to be_present
      end
    end

    describe "comments and communications on the edit page" do
      it "renders the combined comments and communications section" do
        get edit_story_url(published_story)
        expect(response.body).to include("Comments &amp; communications")
        expect(response.body).to include("Add comment")
        expect(response.body).to include("Add communication")
      end

      it "saves a new comment with its topic, authored by the current user" do
        expect {
          patch story_url(published_story),
                params: { story: { comments_attributes: { "0" => { topic: "Follow-up", body: "Emailed the facilitator" } } } }
        }.to change { published_story.comments.count }.by(1)

        comment = published_story.comments.order(:created_at).last
        expect(comment.body).to eq("Emailed the facilitator")
        expect(comment.topic).to eq("Follow-up")
        expect(comment.created_by).to eq(admin)
      end

      it "logs a communication against the story" do
        expect {
          patch story_url(published_story),
                params: { story: { notifications_attributes: { "0" => { email_subject: "Called the facilitator" } } } }
        }.to change { published_story.notifications.count }.by(1)

        note = published_story.notifications.last
        expect(note.noticeable).to eq(published_story)
        expect(note.email_subject).to eq("Called the facilitator")
        expect(note.recipient_email).to eq(published_story.communications_email.presence || "n/a")
      end
    end
  end

  # ==========================================================
  # REGULAR USER (authenticated, not admin)
  # ==========================================================
  describe "as regular_user" do
    before { sign_in regular_user }

    describe "GET /index" do
      it "only shows published stories" do
        get stories_url, params: {}, headers: { "Turbo-Frame" => "stories_results" }

        expect(response.body).to include(published_story.title)
        expect(response.body).to include(public_story.title)
        expect(response.body).not_to include(private_story.title)
      end

      it "never shows funder-only stories" do
        get stories_url, params: {}, headers: { "Turbo-Frame" => "stories_results" }
        expect(response.body).not_to include(funder_only_story.title)
      end

      it "does not show Details button for external stories" do
        external_story = create(:story, :published, title: "External Story", website_url: "https://example.com")
        get stories_url, params: {}, headers: { "Turbo-Frame" => "stories_results" }
        expect(response.body).not_to include("Details")
        expect(response.body).to include('href="https://example.com"')
      end
    end

    describe "GET /show" do
      it "can view published story" do
        get story_url(published_story)
        expect(response).to have_http_status(:ok)
      end

      it "cannot view private story" do
        get story_url(private_story)
        expect(response).to redirect_to(root_path)
      end

      it "cannot view a funder-only story even though it is published and public" do
        get story_url(funder_only_story)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /create" do
      it "is unauthorized" do
        post stories_url, params: { story: base_attributes }
        expect(response).to redirect_to(root_path)
      end
    end
  end

  # ==========================================================
  # GUEST (not authenticated)
  # ==========================================================
  describe "as guest" do
    describe "GET /index" do
      it "only shows publicly_visible stories" do
        get stories_url, params: {}, headers: { "Turbo-Frame" => "stories_results" }

        expect(response.body).to include(public_story.title)
        expect(response.body).not_to include(published_story.title)
        expect(response.body).not_to include(private_story.title)
        expect(response.body).not_to include(funder_only_story.title)
      end
    end

    describe "GET /show" do
      it "can view publicly visible story" do
        get story_url(public_story)
        expect(response).to have_http_status(:ok)
      end

      it "resolves a story by its slugged param" do
        get story_url(public_story)
        expect(public_story.to_param).to match(/\A\d+-/)
        expect(response).to have_http_status(:ok)
      end

      it "still resolves a story by its bare numeric id" do
        get story_url(id: public_story.id)
        expect(response).to have_http_status(:ok)
      end

      it "cannot view published-only story" do
        get story_url(published_story)
        expect(response).to redirect_to(root_path)
      end
    end

    describe "POST /create" do
      it "redirects to new user session path" do
        post stories_url, params: { story: base_attributes }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
