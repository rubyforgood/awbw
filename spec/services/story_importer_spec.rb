require "rails_helper"
require "csv"

RSpec.describe StoryImporter do
  let(:import_user) { create(:user) }
  let!(:pending_status) { create(:organization_status, name: "Pending") }
  let!(:adult_wt) { create(:windows_type, :adult) }
  let!(:children_wt) { create(:windows_type, :children) }
  let!(:combined_wt) { create(:windows_type, :combined) }

  # Minimal subset of the WordPress export columns the importer reads.
  let(:headers) do
    %w[
      ID Title Content Excerpt Status organization_name story_workshop_name
      story_youtube_url showhide_the_name Tags Categories state
      facilitator_name facilitator_last_name facilitator_email home_top_featured_story Date
    ] + [ "Image URL", "Image Alt Text" ]
  end

  # Held in an array so the Tempfiles aren't garbage-collected (and deleted)
  # before the importer reads them.
  let(:tempfiles) { [] }

  def csv_file(rows)
    file = Tempfile.new([ "stories", ".csv" ])
    tempfiles << file
    CSV.open(file.path, "w", write_headers: true, headers: headers) do |csv|
      rows.each { |row| csv << headers.map { |h| row[h] } }
    end
    file.path
  end

  # A non-AWBW facilitator by default (full name, no existing super_user), so a
  # base row yields both a StoryIdea and its connected Story.
  def base_row(overrides = {})
    {
      "ID" => "1",
      "Title" => "A story of healing",
      "Content" => "<p>Once upon a time.</p>",
      "Status" => "publish",
      "organization_name" => "A Greater Hope",
      "story_workshop_name" => "Adult Windows Workshop",
      "Tags" => "Adults",
      "Categories" => "Domestic Violence",
      "showhide_the_name" => "display_full_name",
      "facilitator_name" => "Jamie",
      "facilitator_last_name" => "Rivera"
    }.merge(overrides)
  end

  def import(rows, **opts)
    described_class.new(csv_path: csv_file(rows), import_user: import_user, **opts).call
  end

  # An existing AWBW staff person (has a super_user account) matching a facilitator.
  def awbw_staff(first, last)
    person = create(:person, first_name: first, last_name: last)
    person.user.update!(super_user: true)
    person
  end

  describe "record creation" do
    it "creates a Story for every row (published from the WordPress status)" do
      import([ base_row, base_row("ID" => "2", "Title" => "Draft one", "Status" => "draft") ])

      expect(Story.count).to eq(2)
      expect(Story.find_by(title: "A story of healing").published).to be(true)
      expect(Story.find_by(title: "Draft one").published).to be(false)
    end

    it "also creates a StoryIdea promoted into the story for a non-AWBW author" do
      import([ base_row ])

      story = Story.sole
      expect(story.story_idea).to eq(StoryIdea.sole)
      expect(story.author).to eq(Person.find_by(first_name: "Jamie", last_name: "Rivera"))
    end

    it "creates only a Story (no idea) when the author is AWBW staff" do
      awbw_staff("Nora", "Staff")
      import([ base_row("facilitator_name" => "Nora", "facilitator_last_name" => "Staff") ])

      expect(Story.count).to eq(1)
      expect(StoryIdea.count).to eq(0)
    end

    it "creates a Story-only and keeps the name as a comment when the author can't resolve" do
      import([ base_row("facilitator_name" => "Teena", "facilitator_last_name" => "") ])

      story = Story.sole
      expect(StoryIdea.count).to eq(0)
      expect(story.author).to be_nil
      expect(story.comments.pluck(:body)).to include(a_string_matching(/Teena/))
    end

    it "skips a row whose title already exists" do
      create(:story, title: "A story of healing")
      result = import([ base_row ])

      expect(result.skipped).to include(a_string_matching(/already exists/))
      expect(Story.where(title: "A story of healing").count).to eq(1)
    end

    it "skips rows with a blank title" do
      result = import([ base_row("Title" => "") ])

      expect(result.skipped).to include(a_string_matching(/blank title/))
      expect(Story.count).to eq(0)
    end
  end

  describe "field handling" do
    it "sets author_credit_preference from showhide_the_name" do
      import([ base_row("showhide_the_name" => "hide_full_name") ])

      expect(Story.sole.author_credit_preference).to eq("anonymous")
    end

    it "preserves the original WordPress date as created_at" do
      import([ base_row("Date" => "2021-07-11 10:07:53") ])

      expect(Story.sole.created_at.to_date).to eq(Date.new(2021, 7, 11))
      expect(StoryIdea.sole.created_at.to_date).to eq(Date.new(2021, 7, 11))
    end

    it "converts the export's raw-newline paragraphs into HTML" do
      import([ base_row("Content" => "Line one.\r\n\r\nLine two.") ])

      expect(Story.sole.rhino_body.to_plain_text).to match(/Line one\..*\n.*Line two/m)
    end

    it "links a story to an existing workshop on an exact title match" do
      workshop = create(:workshop, title: "Anger Volcano")
      import([ base_row("story_workshop_name" => "Anger Volcano") ])

      expect(Story.sole.workshop).to eq(workshop)
      expect(Story.sole.external_workshop_title).to be_blank
    end

    it "keeps the free-text workshop title when there is no exact match" do
      import([ base_row("story_workshop_name" => "Some Unlisted Workshop") ])

      expect(Story.sole.workshop).to be_nil
      expect(Story.sole.external_workshop_title).to eq("Some Unlisted Workshop")
    end

    it "marks the story featured when a featured flag is set" do
      import([ base_row("home_top_featured_story" => "1") ])

      expect(Story.sole.featured).to be(true)
    end
  end

  describe "organizations" do
    it "decodes HTML entities in the organization name and reuses the org" do
      import([
        base_row("ID" => "1", "Title" => "A", "organization_name" => "Smith &amp; Co"),
        base_row("ID" => "2", "Title" => "B", "organization_name" => "Smith & Co")
      ])

      expect(Organization.where("LOWER(name) = ?", "smith & co").count).to eq(1)
    end

    it "creates no organization for a name mapped to SKIP" do
      stub_const("StoryImporter::ORG_BY_NAME", { "junk org" => "SKIP" })
      import([ base_row("organization_name" => "Junk Org") ])

      expect(Organization.where("LOWER(name) = ?", "junk org")).not_to exist
      expect(Story.sole.organization).to be_nil
    end
  end

  describe "author profile side effects" do
    it "creates a facilitator affiliation for a non-AWBW author" do
      import([ base_row ])

      author = Person.find_by(first_name: "Jamie", last_name: "Rivera")
      org = Organization.find_by("LOWER(name) = ?", "a greater hope")
      expect(Affiliation.where(person: author, organization: org, title: "Facilitator")).to exist
    end

    it "syncs display_name_preference from the credit when it is still the default" do
      import([ base_row("showhide_the_name" => "display_first_name") ])

      expect(Person.find_by(first_name: "Jamie", last_name: "Rivera").display_name_preference).to eq("first_name_only")
    end

    it "honors a non-default profile preference already set on the person" do
      create(:person, first_name: "Jamie", last_name: "Rivera", display_name_preference: "last_name_only")
      import([ base_row("showhide_the_name" => "display_first_name") ])

      expect(Person.find_by(first_name: "Jamie", last_name: "Rivera").display_name_preference).to eq("last_name_only")
    end
  end

  describe "windows type" do
    it "derives windows type from pipe-delimited multi-audience tags" do
      import([
        base_row("ID" => "1", "Title" => "Kids only", "Tags" => "children|teens"),
        base_row("ID" => "2", "Title" => "Mixed ages", "Tags" => "adults|children"),
        base_row("ID" => "3", "Title" => "Only grown", "Tags" => "adults")
      ])

      expect(Story.find_by(title: "Kids only").windows_type).to eq(children_wt)
      expect(Story.find_by(title: "Mixed ages").windows_type).to eq(combined_wt)
      expect(Story.find_by(title: "Only grown").windows_type).to eq(adult_wt)
    end
  end

  describe "tagging via the translations map" do
    let(:age_range) { create(:category_type, name: "AgeRange") }
    let(:story_population) { create(:category_type, name: "StoryPopulation") }
    let(:emotional_theme) { create(:category_type, name: "EmotionalTheme") }

    it "tags a matching sector via the category mapping" do
      sector = create(:sector, name: "Substance Use/Recovery")
      import([ base_row("Categories" => "Substance Abuse Recovery") ])

      expect(Story.sole.sectors).to include(sector)
    end

    it "warns when a category maps to a sector that does not exist" do
      result = import([ base_row("Categories" => "Facilitator Spotlights") ])

      expect(result.warnings).to include(a_string_matching(/no Sector match/))
      expect(Story.sole.sectors).to be_empty
    end

    it "applies both the AgeRange and the underscore StoryPopulation for an age-twin tag" do
      adults_age = create(:category, category_type: age_range, name: "Adults")
      adults_population = create(:category, category_type: story_population, name: "Adults_")
      import([ base_row("Tags" => "Adults") ])

      expect(Story.sole.categories).to include(adults_age, adults_population)
    end

    it "applies a semantic Category overlap alongside the Sector" do
      sector = create(:sector, name: "Grief/Loss")
      grief = create(:category, category_type: emotional_theme, name: "Grief")
      import([ base_row("Categories" => "Grief & Loss") ])

      expect(Story.sole.sectors).to include(sector)
      expect(Story.sole.categories).to include(grief)
    end
  end

  describe "grant linking" do
    let!(:grant) { create(:grant, name: "Cathy Salser Legacy Scholarship") }

    it "links the author to the grant through a scholarship" do
      import([ base_row("Tags" => "Adults|Cathy scholarship") ])

      author = Person.find_by(first_name: "Jamie", last_name: "Rivera")
      expect(Story.sole.author).to eq(author)
      expect(Scholarship.where(recipient: author, grant: grant)).to exist
    end

    it "warns and skips the link when the author has no last name" do
      result = import([ base_row("Tags" => "Cathy scholarship",
                                 "facilitator_name" => "Teena", "facilitator_last_name" => "") ])

      expect(result.warnings).to include(a_string_matching(/author unresolved/))
      expect(Scholarship.count).to eq(0)
    end
  end

  describe "anonymous contributions" do
    it "flags the author's profile as anonymous for an anonymous credit" do
      import([ base_row("showhide_the_name" => "hide_full_name") ])

      author = Person.find_by(first_name: "Jamie", last_name: "Rivera")
      expect(author.anonymous_contributions).to be(true)
    end
  end

  describe "dry run" do
    it "writes nothing but reports what would be created" do
      result = import([ base_row ], dry_run: true)

      expect(Story.count).to eq(0)
      expect(StoryIdea.count).to eq(0)
      expect(Person.count).to eq(0)
      expect(result.ideas_created).to eq(1)
      expect(result.stories_created).to eq(1)
    end

    it "builds a per-row preview of the matched and new records" do
      create(:sector, name: "Domestic Violence")
      result = import([ base_row ], dry_run: true)

      preview = result.previews.sole
      expect(preview.title).to eq("A story of healing")
      expect(preview.will_publish).to be(true)
      expect(preview.creates_story).to be(true)
      expect(preview.creates_idea).to be(true)
      expect(preview.organization_new).to be(true)
      expect(preview.author_new).to be(true)
      expect(preview.sectors).to include("Domestic Violence")
    end

    it "records a skip reason in the preview for a blank title" do
      result = import([ base_row("Title" => "") ], dry_run: true)

      expect(result.previews.sole.skipped_reason).to eq("blank title")
    end
  end

  describe "image import" do
    let(:image_row) do
      base_row(
        "Image URL" => "https://ex.com/cover.jpg|https://ex.com/two.jpg| ",
        "Image Alt Text" => "Healing hands"
      )
    end

    it "enqueues a StoryAssetImportJob for the story with the row's image URLs" do
      import([ image_row ])

      expect(StoryAssetImportJob).to have_been_enqueued
        .with(Story.sole, [ "https://ex.com/cover.jpg", "https://ex.com/two.jpg" ], title: "Healing hands")
    end

    it "counts the queued images in the result" do
      result = import([ image_row ])
      expect(result.images_enqueued).to eq(2)
    end

    it "does not enqueue anything on a dry run, but counts the images in the preview" do
      result = import([ image_row ], dry_run: true)

      expect(StoryAssetImportJob).not_to have_been_enqueued
      expect(result.previews.sole.images).to eq(2)
      expect(result.images_enqueued).to eq(0)
    end

    it "does not enqueue a job when the row has no image URL" do
      expect {
        import([ base_row ])
      }.not_to have_enqueued_job(StoryAssetImportJob)
    end
  end
end
