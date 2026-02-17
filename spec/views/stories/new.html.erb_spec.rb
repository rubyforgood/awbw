require 'rails_helper'

RSpec.describe "stories/new", type: :view do
  let(:user) { create(:user) }

  before(:each) do
    assign(:windows_types, [])
    assign(:workshops, [])
    assign(:organizations, [])
    assign(:users, [])
    assign(:sectors, [])
    assign(:categories_grouped, [])
    assign(:story_ideas, [])
    allow(view).to receive(:current_user).and_return(user)
    allow(view).to receive(:allowed_to?).and_return(false)
  end

  it "renders new story form" do
    assign(:story, Story.new)

    render

    assert_select "form[action=?][method=?]", stories_path, "post" do
      assert_select "select[name=?]", "story[windows_type_id]"
      assert_select "select[name=?]", "story[organization_id]"
      assert_select "select[name=?]", "story[workshop_id]"
      assert_select "input[name=?][type=?]", "story[rhino_body]", "hidden"
      assert_select "textarea[name=?]", "story[youtube_url]"
      assert_select "select[name=?]", "story[created_by_id]"
    end
  end

  context "when promoted from a story idea" do
    let(:story_idea) do
      create(:story_idea,
             created_by: user,
             updated_by: user,
             title: "Inspiring Journey",
             body: "A powerful story about healing",
             youtube_url: "https://youtube.com/watch?v=abc123")
    end

    let(:story) do
      Story.new(
        rhino_body: story_idea.body,
        organization_id: story_idea.organization_id,
        workshop_id: story_idea.workshop_id,
        windows_type_id: story_idea.windows_type_id,
        youtube_url: story_idea.youtube_url,
        story_idea_id: story_idea.id
      )
    end

    before do
      assign(:story, story)
      assign(:story_idea, story_idea)
      assign(:story_ideas, StoryIdea.where(id: story_idea.id))
      assign(:windows_types, WindowsType.where(id: story_idea.windows_type_id))
      assign(:workshops, Workshop.where(id: story_idea.workshop_id))
      assign(:organizations, Organization.where(id: story_idea.organization_id))
    end

    it "pre-fills windows_type_id from story idea" do
      render

      assert_select "form[action=?]", stories_path do
        assert_select "select[name=?]", "story[windows_type_id]" do
          assert_select "option[selected][value=?]", story_idea.windows_type_id.to_s
        end
      end
    end

    it "pre-fills workshop_id from story idea" do
      render

      assert_select "form[action=?]", stories_path do
        assert_select "select[name=?]", "story[workshop_id]" do
          assert_select "option[selected][value=?]", story_idea.workshop_id.to_s
        end
      end
    end

    it "pre-fills organization_id from story idea" do
      render

      assert_select "form[action=?]", stories_path do
        assert_select "select[name=?]", "story[organization_id]" do
          assert_select "option[selected][value=?]", story_idea.organization_id.to_s
        end
      end
    end

    it "pre-fills youtube_url from story idea" do
      render

      assert_select "form[action=?]", stories_path do
        assert_select "textarea[name=?]", "story[youtube_url]", text: story_idea.youtube_url
      end
    end

    it "pre-fills story_idea_id from story idea" do
      render

      assert_select "form[action=?]", stories_path do
        assert_select "select[name=?]", "story[story_idea_id]" do
          assert_select "option[selected][value=?]", story_idea.id.to_s
        end
      end
    end

    it "shows the promote idea assets checkbox when story idea has attachments" do
      primary = story_idea.build_primary_asset
      primary.file.attach(
        io: StringIO.new("fake image data"),
        filename: "test.png",
        content_type: "image/png"
      )
      primary.save!
      assign(:story_idea, story_idea.reload)

      render

      assert_select "input[name=?][type=checkbox]", "promote_idea_assets"
      expect(rendered).to include("Story idea attachments")
    end

    it "displays story idea author credit" do
      render

      expect(rendered).to include("Story idea author credit")
      expect(rendered).to include(story_idea.author_credit)
    end

    it "displays story idea publish preferences" do
      render

      expect(rendered).to include("publish preferences")
      expect(rendered).to include(story_idea.publish_preferences)
    end

    context "with sectors and categories from story idea" do
      let(:sector) { create(:sector, :published, name: "Domestic Violence") }
      let(:category_type) { create(:category_type, :published, name: "StoryPopulation", story_specific: true, display_text: "Who is your story about?") }
      let(:category) { create(:category, :published, name: "Adults", category_type: category_type) }

      before do
        story_idea.sectors << sector
        story_idea.categories << category

        assign(:story, story)
        assign(:preselected_sector_ids, [ sector.id ])
        assign(:preselected_category_ids, [ category.id ])
        assign(:sectors, [ sector ])
        assign(:categories_grouped, [ [ category_type, [ category ] ] ])
      end

      it "pre-checks sectors from story idea" do
        render

        assert_select "input[type=checkbox][name=?][value=?][checked]",
                      "story[sector_ids][]", sector.id.to_s
      end

      it "pre-checks categories from story idea" do
        render

        assert_select "input[type=checkbox][name=?][value=?][checked]",
                      "story[category_ids][]", category.id.to_s
      end
    end
  end

  context "tags display" do
    let(:story_population_type) do
      create(:category_type, :published,
             name: "StoryPopulation",
             story_specific: true,
             display_text: "Who is your story about?")
    end

    let(:general_type) do
      create(:category_type, :published, name: "AgeRange")
    end

    let(:population_category) do
      create(:category, :published, name: "Adults", category_type: story_population_type)
    end

    let(:general_category) do
      create(:category, :published, name: "Children 0-5", category_type: general_type)
    end

    let(:sector) { create(:sector, :published, name: "Domestic Violence") }

    before do
      assign(:story, Story.new)
      assign(:sectors, [ sector ])
      assign(:categories_grouped, [
         [ story_population_type, [ population_category ] ],
        [ general_type, [ general_category ] ]
      ])
    end

    it "displays sector question text instead of just 'Sectors'" do
      render

      expect(rendered).to include(Sector::STORY_DISPLAY_TEXT)
    end

    it "displays sector checkboxes" do
      render

      assert_select "input[type=checkbox][name=?][value=?]",
                    "story[sector_ids][]", sector.id.to_s
      expect(rendered).to include("Domestic Violence")
    end

    it "displays story-specific category type with display_label" do
      render

      expect(rendered).to include("Who is your story about?")
    end

    it "displays story-specific category checkboxes" do
      render

      assert_select "input[type=checkbox][name=?][value=?]",
                    "story[category_ids][]", population_category.id.to_s
      expect(rendered).to include("Adults")
    end

    it "displays general category type with titleized name" do
      render

      expect(rendered).to include("Age Range")
    end

    it "displays general category checkboxes" do
      render

      assert_select "input[type=checkbox][name=?][value=?]",
                    "story[category_ids][]", general_category.id.to_s
      expect(rendered).to include("Children 0-5")
    end

    it "shows story-specific types before general types" do
      render

      population_pos = rendered.index("Who is your story about?")
      age_range_pos = rendered.index("Age Range")
      expect(population_pos).to be < age_range_pos
    end
  end
end
