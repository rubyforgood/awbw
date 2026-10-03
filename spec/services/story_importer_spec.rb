require "rails_helper"
require "csv"

RSpec.describe StoryImporter do
  let(:import_user) { create(:user) }
  let!(:pending_status) { create(:organization_status, name: "Pending") }
  let!(:adult_wt) { create(:windows_type, :adult) }
  let!(:children_wt) { create(:windows_type, :children) }
  let!(:combined_wt) { create(:windows_type, :combined) }

  let(:headers) { StoryImporter::TEMPLATE_HEADERS }

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

  # A non-AWBW facilitator by default (full name, no existing super_user), and an
  # import_action that mentions a story idea, so a base row yields both a StoryIdea
  # and its connected Story.
  def base_row(overrides = {})
    {
      "wp_id" => "1",
      "title" => "A story of healing",
      "import_action" => "Published story + story idea",
      "content" => "<p>Once upon a time.</p>",
      "published" => "yes",
      "organization_name" => "A Greater Hope",
      "workshop" => "External title: Adult Windows Workshop",
      "window_type" => "Adult",
      "sectors" => "Domestic Violence",
      "categories" => "AgeRange: Adults",
      "name_display" => "full name",
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
    it "creates a Story for every row (published from the published column)" do
      import([ base_row, base_row("wp_id" => "2", "title" => "Draft one", "published" => "no") ])

      expect(Story.count).to eq(2)
      expect(Story.find_by(title: "A story of healing").published).to be(true)
      expect(Story.find_by(title: "Draft one").published).to be(false)
    end

    it "also creates a StoryIdea promoted into the story when import_action mentions one" do
      import([ base_row ])

      story = Story.sole
      expect(story.story_idea).to eq(StoryIdea.sole)
      expect(story.author).to eq(Person.find_by(first_name: "Jamie", last_name: "Rivera"))
    end

    it "creates only a Story when import_action is just a published story" do
      import([ base_row("import_action" => "Published story") ])

      expect(Story.count).to eq(1)
      expect(StoryIdea.count).to eq(0)
    end

    it "falls back to the author when import_action is blank" do
      awbw_staff("Nora", "Staff")
      import([
        base_row("import_action" => "", "wp_id" => "1", "title" => "By a facilitator"),
        base_row("import_action" => "", "wp_id" => "2", "title" => "By staff",
                 "facilitator_name" => "Nora", "facilitator_last_name" => "Staff")
      ])

      expect(Story.find_by(title: "By a facilitator").story_idea).to be_present
      expect(Story.find_by(title: "By staff").story_idea).to be_nil
    end

    it "creates a Story-only and keeps the name as a comment when the author can't resolve" do
      import([ base_row("import_action" => "Published story",
                        "facilitator_name" => "Teena", "facilitator_last_name" => "") ])

      story = Story.sole
      expect(StoryIdea.count).to eq(0)
      expect(story.author).to be_nil
      expect(story.comments.pluck(:body)).to include(a_string_matching(/Teena/))
    end

    it "updates an existing story's metadata but keeps its body, without duplicating it" do
      existing = create(:story, title: "A story of healing", published: false,
                                rhino_body: "<p>Original body kept.</p>")

      result = import([ base_row ])

      expect(Story.where(title: "A story of healing").count).to eq(1)
      existing.reload
      expect(existing.rhino_body.to_plain_text).to eq("Original body kept.")
      expect(existing.published).to be(true)
      expect(existing.organization.name).to eq("A Greater Hope")
      expect(result.stories_updated).to eq(1)
      expect(result.stories_created).to eq(0)
    end

    it "links the imported workshop to an existing story without creating an idea" do
      create(:story, title: "A story of healing", workshop: nil)

      expect { import([ base_row ]) }.not_to change(StoryIdea, :count)

      story = Story.find_by(title: "A story of healing")
      expect(story.story_workshops.map(&:external_workshop_title)).to include("Adult Windows Workshop")
    end

    it "marks the row as an update in the preview rather than skipping it" do
      create(:story, title: "A story of healing")

      result = import([ base_row ], dry_run: true)

      expect(result.previews.sole.skipped_reason).to be_nil
      expect(result.previews.sole.updates_story).to be(true)
    end

    it "skips rows with a blank title" do
      result = import([ base_row("title" => "") ])

      expect(result.skipped).to include(a_string_matching(/blank title/))
      expect(Story.count).to eq(0)
    end

    it "skips rows the sheet flagged as skipped in import_action" do
      result = import([ base_row("import_action" => "Skipped — duplicate") ])

      expect(result.skipped).to include(a_string_matching(/duplicate/))
      expect(result.previews.sole.skipped_reason).to eq("duplicate")
      expect(Story.count).to eq(0)
    end
  end

  describe "field handling" do
    it "sets author_credit_preference from the anonymous column" do
      import([ base_row("anonymous" => "anonymous") ])

      expect(Story.sole.author_credit_preference).to eq("anonymous")
    end

    it "sets author_credit_preference from name_display" do
      import([ base_row("name_display" => "first name only") ])

      expect(Story.sole.author_credit_preference).to eq("first_name_only")
    end

    it "preserves the publish date as created_at" do
      import([ base_row("published_date" => "2021-07-11 10:07:53") ])

      expect(Story.sole.created_at.to_date).to eq(Date.new(2021, 7, 11))
      expect(StoryIdea.sole.created_at.to_date).to eq(Date.new(2021, 7, 11))
    end

    it "converts raw-newline paragraphs into HTML" do
      import([ base_row("content" => "Line one.\r\n\r\nLine two.") ])

      expect(Story.sole.rhino_body.to_plain_text).to match(/Line one\..*\n.*Line two/m)
    end

    it "links a story to an existing workshop on an exact title match (ignoring the prefix)" do
      workshop = create(:workshop, title: "Anger Volcano")
      import([ base_row("workshop" => "Matched workshop: Anger Volcano") ])

      expect(Story.sole.workshop).to eq(workshop)
      expect(Story.sole.workshops).to eq([ workshop ])
      expect(Story.sole.external_workshop_title).to be_blank
    end

    it "keeps the free-text workshop title when there is no exact match" do
      import([ base_row("workshop" => "External title: Some Unlisted Workshop") ])

      expect(Story.sole.workshop).to be_nil
      expect(Story.sole.external_workshop_title).to eq("Some Unlisted Workshop")
      expect(Story.sole.story_workshops.sole.external_workshop_title).to eq("Some Unlisted Workshop")
    end

    it "marks the story featured when the featured column is yes" do
      import([ base_row("featured" => "yes") ])

      expect(Story.sole.featured).to be(true)
    end
  end

  describe "organizations" do
    it "decodes HTML entities in the organization name and reuses the org" do
      import([
        base_row("wp_id" => "1", "title" => "A", "organization_name" => "Smith &amp; Co"),
        base_row("wp_id" => "2", "title" => "B", "organization_name" => "Smith & Co")
      ])

      expect(Organization.where("LOWER(name) = ?", "smith & co").count).to eq(1)
    end

    it "creates no organization when the name is SKIP" do
      import([ base_row("import_action" => "Published story", "organization_name" => "SKIP") ])

      expect(Organization.count).to eq(0)
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
      import([ base_row("name_display" => "first name only") ])

      expect(Person.find_by(first_name: "Jamie", last_name: "Rivera").display_name_preference).to eq("first_name_only")
    end

    it "honors a non-default profile preference already set on the person" do
      create(:person, first_name: "Jamie", last_name: "Rivera", display_name_preference: "last_name_only")
      import([ base_row("name_display" => "first name only") ])

      expect(Person.find_by(first_name: "Jamie", last_name: "Rivera").display_name_preference).to eq("last_name_only")
    end
  end

  describe "windows type" do
    it "trusts the window_type column" do
      import([
        base_row("wp_id" => "1", "title" => "Kids only", "window_type" => "Children"),
        base_row("wp_id" => "2", "title" => "Mixed ages", "window_type" => "Combined"),
        base_row("wp_id" => "3", "title" => "Only grown", "window_type" => "Adult")
      ])

      expect(Story.find_by(title: "Kids only").windows_type).to eq(children_wt)
      expect(Story.find_by(title: "Mixed ages").windows_type).to eq(combined_wt)
      expect(Story.find_by(title: "Only grown").windows_type).to eq(adult_wt)
    end

    it "warns and defaults to Adult for an unknown window type" do
      result = import([ base_row("window_type" => "Martians") ])

      expect(result.warnings).to include(a_string_matching(/unknown window type/))
      expect(Story.sole.windows_type).to eq(adult_wt)
    end
  end

  describe "tagging from the resolved columns" do
    let(:age_range) { create(:category_type, name: "AgeRange") }
    let(:emotional_theme) { create(:category_type, name: "EmotionalTheme") }

    it "tags sectors by name from the sectors column" do
      sector = create(:sector, name: "Substance Use/Recovery")
      import([ base_row("sectors" => "Substance Use/Recovery") ])

      expect(Story.sole.sectors).to include(sector)
    end

    it "warns when a sector name does not exist" do
      result = import([ base_row("sectors" => "Imaginary Sector") ])

      expect(result.warnings).to include(a_string_matching(/no Sector match/))
    end

    it "tags categories by Type: Name from the categories column" do
      adults = create(:category, category_type: age_range, name: "Adults")
      grief = create(:category, category_type: emotional_theme, name: "Grief")
      import([ base_row("categories" => "AgeRange: Adults | EmotionalTheme: Grief") ])

      expect(Story.sole.categories).to include(adults, grief)
    end

    it "warns when a category does not exist" do
      result = import([ base_row("categories" => "AgeRange: Nope") ])

      expect(result.warnings).to include(a_string_matching(/no Category match/))
    end
  end

  describe "grant linking" do
    let!(:grant) { create(:grant, name: "Cathy Salser Legacy Scholarship") }

    it "links the author to the grant through a scholarship" do
      import([ base_row("grants" => "Cathy Salser Legacy Scholarship") ])

      author = Person.find_by(first_name: "Jamie", last_name: "Rivera")
      expect(Story.sole.author).to eq(author)
      expect(Scholarship.where(recipient: author, grant: grant)).to exist
    end

    it "warns and skips the link when the author has no last name" do
      result = import([ base_row("grants" => "Cathy Salser Legacy Scholarship",
                                 "facilitator_name" => "Teena", "facilitator_last_name" => "") ])

      expect(result.warnings).to include(a_string_matching(/author unresolved/))
      expect(Scholarship.count).to eq(0)
    end
  end

  describe "anonymous contributions" do
    it "flags the author's profile as anonymous for an anonymous credit" do
      import([ base_row("anonymous" => "anonymous") ])

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
      result = import([ base_row("title" => "") ], dry_run: true)

      expect(result.previews.sole.skipped_reason).to eq("blank title")
    end
  end

  describe "image import" do
    let(:image_row) do
      base_row(
        "image_urls" => "https://ex.com/cover.jpg|https://ex.com/two.jpg| ",
        "image_alt_titles" => "Healing hands"
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
