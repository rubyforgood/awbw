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

  # A non-AWBW facilitator with an organization, so a base row yields a Story and
  # a StoryIdea promoted into it.
  def base_row(overrides = {})
    {
      "wp_id" => "1",
      "title" => "A story of healing",
      "status" => "Published story + story idea",
      "content" => "<p>Once upon a time.</p>",
      "published" => "yes",
      "organization_name" => "Example Family Services",
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

  describe "record creation" do
    it "creates a Story and a promoted StoryIdea for every importable row" do
      import([ base_row ])

      story = Story.sole
      expect(story.story_idea).to eq(StoryIdea.sole)
      expect(story.author).to eq(Person.find_by(first_name: "Jamie", last_name: "Rivera"))
    end

    it "creates an org-less Story and still promotes its idea when the organization is blank" do
      import([ base_row("organization_name" => "") ])

      expect(Story.sole.organization).to be_nil
      expect(Story.sole.story_idea).to eq(StoryIdea.sole)
      expect(StoryIdea.sole.organization).to be_nil
    end

    it "credits no author and keeps the name as a comment when the author can't resolve" do
      import([ base_row("facilitator_name" => "Marguerite", "facilitator_last_name" => "") ])

      story = Story.sole
      expect(story.author).to be_nil
      expect(story.comments.pluck(:body)).to include(a_string_matching(/Marguerite/))
    end

    it "renames a duplicate title to [COPY N] instead of skipping" do
      create(:story, title: "A story of healing")
      import([ base_row ])

      expect(Story.count).to eq(2)
      expect(Story.find_by(title: "[COPY 1] A story of healing")).to be_present
    end

    it "skips rows with a blank title" do
      result = import([ base_row("title" => "") ])

      expect(result.skipped).to include(a_string_matching(/blank title/))
      expect(Story.count).to eq(0)
    end

    it "skips rows the sheet flagged as skipped in the status column" do
      result = import([ base_row("status" => "Skipped — duplicate") ])

      expect(result.skipped).to include(a_string_matching(/duplicate/))
      expect(result.previews.sole.skipped_reason).to eq("duplicate")
      expect(Story.count).to eq(0)
    end

    it "skips a lower-cased skipped status too" do
      result = import([ base_row("status" => "skipped — duplicate") ])

      expect(result.previews.sole.skipped_reason).to eq("duplicate")
      expect(Story.count).to eq(0)
    end

    it "skips a row whose window type does not match exactly" do
      result = import([ base_row("window_type" => "Martians") ])

      expect(result.skipped).to include(a_string_matching(/unknown window type/))
      expect(Story.count).to eq(0)
    end
  end

  describe "status column" do
    it "promotes a StoryIdea only when the status says story idea" do
      import([ base_row("status" => "Published story + story idea") ])

      expect(StoryIdea.count).to eq(1)
      expect(Story.sole.story_idea).to eq(StoryIdea.sole)
    end

    it "is Story-only when the status is a story without a story idea" do
      import([ base_row("status" => "Published story") ])

      expect(Story.count).to eq(1)
      expect(StoryIdea.count).to eq(0)
      expect(Story.sole.story_idea).to be_nil
    end

    it "publishes a Published story" do
      import([ base_row("status" => "Published story") ])

      expect(Story.sole).to have_attributes(published: true, publicly_visible: true)
    end

    it "leaves a Draft story unpublished but still a story" do
      import([ base_row("status" => "Draft story + story idea") ])

      story = Story.sole
      expect(story).to have_attributes(published: false, publicly_visible: false)
      expect(story.story_idea).to eq(StoryIdea.sole)
    end

    it "promotes an org-less story idea when the status requests one" do
      import([ base_row("status" => "Published story + story idea", "organization_name" => "") ])

      expect(Story.count).to eq(1)
      expect(StoryIdea.count).to eq(1)
      expect(StoryIdea.sole.organization).to be_nil
      expect(Story.sole.story_idea).to eq(StoryIdea.sole)
    end

    it "stays Story-only for an org-less row whose status does not request an idea" do
      import([ base_row("status" => "Published story", "organization_name" => "") ])

      expect(Story.count).to eq(1)
      expect(StoryIdea.count).to eq(0)
    end

    it "falls back to the published column when status is blank" do
      import([ base_row("status" => "", "published" => "no") ])

      expect(Story.sole.published).to be(false)
    end

    it "skips a row flagged Skipped in the status column" do
      result = import([ base_row("status" => "Skipped — duplicate") ])

      expect(result.skipped).to include(a_string_matching(/duplicate/))
      expect(Story.count).to eq(0)
    end

    it "skips a second header row of human labels beneath the snake_case headers" do
      header_echo = {
        "title" => "Title", "status" => "Status", "wp_id" => "WP ID",
        "published" => "Published", "window_type" => "Window type", "name_display" => "Name display"
      }
      result = import([ header_echo, base_row ])

      expect(result.skipped).to include(a_string_matching(/duplicate header row/))
      expect(Story.count).to eq(1)
      expect(Story.sole.title).to eq("A story of healing")
    end
  end

  describe "column header aliases" do
    def labeled_csv(row)
      file = Tempfile.new([ "labeled", ".csv" ])
      tempfiles << file
      CSV.open(file.path, "w", write_headers: true, headers: row.keys) do |csv|
        csv << row.values
      end
      file.path
    end

    it "imports a sheet that uses the review labels instead of snake_case headers" do
      path = labeled_csv(
        "Title" => "A labeled story",
        "Status" => "Published story + story idea",
        "WP ID" => "99",
        "Content" => "<p>Body.</p>",
        "Publish date" => "2021-07-11 10:07:53",
        "Organization" => "Example Family Services",
        "First name" => "Jamie",
        "Last name" => "Rivera",
        "Name display" => "first name only",
        "Workshop" => "External title: Adult Windows Workshop",
        "Sectors" => "Domestic Violence",
        "Window type" => "Adult",
        "Categories" => "AgeRange: Adults",
        "Coauthor first name" => "Sam",
        "Coauthor last name" => "Lee",
        "Coauthor name display" => "first name only",
        "Professional licenses" => "LMFT, LCSW"
      )
      described_class.new(csv_path: path, import_user: import_user).call

      story = Story.sole
      expect(story.title).to eq("A labeled story")
      expect(story.story_idea).to eq(StoryIdea.sole)
      expect(story.author).to have_attributes(first_name: "Jamie", last_name: "Rivera")
      expect(story.co_author).to have_attributes(first_name: "Sam", last_name: "Lee")
      expect(story.author.professional_licenses.pluck(:kind)).to contain_exactly("LMFT", "LCSW")
    end

    it "honors a labeled anonymous credit for either author" do
      path = labeled_csv(
        "Title" => "A labeled story",
        "Status" => "Published story",
        "Content" => "<p>Body.</p>",
        "Window type" => "Adult",
        "First name" => "Jamie",
        "Last name" => "Rivera",
        "Anonymous credit?" => "anonymous",
        "Coauthor first name" => "Sam",
        "Coauthor last name" => "Lee",
        "Coauthor anonymous credit?" => "anonymous"
      )
      described_class.new(csv_path: path, import_user: import_user).call

      expect(Person.find_by(first_name: "Jamie", last_name: "Rivera").anonymous_contributions).to be(true)
      expect(Person.find_by(first_name: "Sam", last_name: "Lee").anonymous_contributions).to be(true)
    end
  end

  describe "title" do
    it "strips HTML from the title" do
      import([ base_row("title" => "<b>Bold</b> Hope") ])

      expect(Story.sole.title).to eq("Bold Hope")
    end
  end

  describe "AWBW rows" do
    it "resolves the mis-filed facilitator and flags their profile anonymous" do
      import([ base_row("facilitator_name" => "AWBW", "facilitator_last_name" => "Marlowe Fenn",
                        "facilitator_email" => "marlowe.fenn@example.org") ])

      author = Person.find_by(first_name: "Marlowe", last_name: "Fenn")
      expect(author).to be_present
      expect(author.anonymous_contributions).to be(true)
      expect(Story.sole.author).to eq(author)
      # Credit is NULL on the story; anonymity comes from the profile.
      expect(Story.sole.author_credit_preference).to be_nil
    end

    it "credits no author for a nameless AWBW row" do
      import([ base_row("facilitator_name" => "AWBW", "facilitator_last_name" => "",
                        "facilitator_email" => "none") ])

      expect(Story.sole.author).to be_nil
    end
  end

  describe "author credit" do
    it "sets the author's profile display preference from name_display" do
      import([ base_row("name_display" => "first name only") ])

      expect(Person.find_by(first_name: "Jamie", last_name: "Rivera").display_name_preference).to eq("first_name_only")
    end

    it "maps every portal name_display option to its preference" do
      {
        "First name" => "first_name_only",
        "first name last initial" => "first_name_last_initial",
        "last name only" => "last_name_only",
        "first and last name" => "full_name"
      }.each_with_index do |(label, pref), i|
        import([ base_row("wp_id" => i.to_s, "title" => "Pref #{i}",
                          "facilitator_name" => "Pref#{i}", "facilitator_last_name" => "Author",
                          "name_display" => label) ])

        expect(Person.find_by(first_name: "Pref#{i}", last_name: "Author").display_name_preference).to eq(pref)
      end
    end

    it "flags the author's profile anonymous for an anonymous credit" do
      import([ base_row("anonymous" => "anonymous") ])

      expect(Person.find_by(first_name: "Jamie", last_name: "Rivera").anonymous_contributions).to be(true)
    end

    it "flags the author anonymous when name_display itself says anonymous" do
      import([ base_row("name_display" => "anonymous") ])

      expect(Person.find_by(first_name: "Jamie", last_name: "Rivera").anonymous_contributions).to be(true)
    end

    it "leaves the story credit NULL (follows the profile) for a single consistent author" do
      import([ base_row("name_display" => "first name only") ])

      expect(Story.sole.author_credit_preference).to be_nil
      expect(Person.find_by(first_name: "Jamie", last_name: "Rivera").display_name_preference).to eq("first_name_only")
    end

    it "captures per-story credit when one author's rows disagree" do
      import([
        base_row("wp_id" => "1", "title" => "Conflict A", "name_display" => "full name"),
        base_row("wp_id" => "2", "title" => "Conflict B", "name_display" => "first name only")
      ])

      expect(Story.find_by(title: "Conflict A").author_credit_preference).to eq("full_name")
      expect(Story.find_by(title: "Conflict B").author_credit_preference).to eq("first_name_only")
    end

    it "honors a non-default profile preference already set on the person" do
      create(:person, first_name: "Jamie", last_name: "Rivera", display_name_preference: "last_name_only")
      import([ base_row("name_display" => "first name only") ])

      expect(Person.find_by(first_name: "Jamie", last_name: "Rivera").display_name_preference).to eq("last_name_only")
    end
  end

  describe "matching the author to an existing person" do
    it "matches on a secondary email and the legal first name" do
      existing = create(:person, user: nil, first_name: "Jim", legal_first_name: "Jamie",
                                 last_name: "Rivera", email: nil, email_2: "jamie@example.org")

      expect {
        import([ base_row("facilitator_email" => "jamie@example.org") ])
      }.not_to change(Person, :count)

      expect(Story.sole.author).to eq(existing)
    end

    it "matches on the person's login email" do
      existing = create(:person, user: create(:user, email: "jamie@example.org"),
                                 first_name: "Jim", legal_first_name: "Jamie", last_name: "Rivera", email: nil)

      expect {
        import([ base_row("facilitator_email" => "jamie@example.org") ])
      }.not_to change(Person, :count)

      expect(Story.sole.author).to eq(existing)
    end

    it "does not match a different person who merely shares the email and last name" do
      create(:person, user: nil, first_name: "Dana", last_name: "Rivera", email: "shared@example.org")

      expect {
        import([ base_row("facilitator_email" => "shared@example.org") ])
      }.to change(Person, :count).by(1)

      expect(Story.sole.author).to have_attributes(first_name: "Jamie", last_name: "Rivera")
    end

    it "still matches on an exact name when the row carries no email" do
      existing = create(:person, user: nil, first_name: "Jamie", last_name: "Rivera", email: nil)

      expect { import([ base_row ]) }.not_to change(Person, :count)

      expect(Story.sole.author).to eq(existing)
    end
  end

  describe "second author" do
    def co_author_row(overrides = {})
      base_row({
        "co_facilitator_name" => "Noor",
        "co_facilitator_last_name" => "Smith",
        "co_facilitator_email" => "noor.smith@example.org",
        "co_name_display" => "first name only"
      }.merge(overrides))
    end

    it "credits a second author with its own profile preference" do
      import([ co_author_row ])

      co_author = Person.find_by(first_name: "Noor", last_name: "Smith")
      expect(Story.sole.co_author).to eq(co_author)
      expect(co_author.display_name_preference).to eq("first_name_only")
    end

    it "credits both authors on the promoted story idea too" do
      import([ co_author_row ])

      idea = StoryIdea.sole
      expect(idea.author).to eq(Person.find_by(first_name: "Jamie", last_name: "Rivera"))
      expect(idea.co_author).to eq(Person.find_by(first_name: "Noor", last_name: "Smith"))
    end

    it "leaves the co-author's story credit NULL for a consistent author" do
      import([ co_author_row ])

      expect(Story.sole.co_author_credit_preference).to be_nil
    end

    it "flags the co-author anonymous from its own column" do
      import([ co_author_row("co_anonymous" => "anonymous") ])

      expect(Person.find_by(first_name: "Noor", last_name: "Smith").anonymous_contributions).to be(true)
    end

    it "does not set a co-author equal to the first author" do
      import([ co_author_row("co_facilitator_name" => "Jamie", "co_facilitator_last_name" => "Rivera",
                             "co_facilitator_email" => "") ])

      expect(Story.sole.co_author).to be_nil
    end

    it "does not set a co-author equal to the first author when only one side names an email" do
      import([ co_author_row("facilitator_email" => "jamie@example.org",
                             "co_facilitator_name" => "Jamie", "co_facilitator_last_name" => "Rivera",
                             "co_facilitator_email" => "") ])

      expect(Story.sole.co_author).to be_nil
    end

    it "keeps a second author with no first author as a comment" do
      import([ co_author_row("facilitator_name" => "", "facilitator_last_name" => "") ])

      expect(Story.sole.author).to be_nil
      expect(Story.sole.co_author).to be_nil
      expect(Story.sole.comments.pluck(:body)).to include(a_string_matching(/Noor Smith/))
    end
  end

  describe "workshop" do
    it "links a story (and its idea) to an existing workshop via the join on an exact match" do
      workshop = create(:workshop, title: "Sample Anger Workshop")
      import([ base_row("workshop" => "Matched workshop: Sample Anger Workshop") ])

      expect(Story.sole.workshops).to contain_exactly(workshop)
      expect(StoryIdea.sole.workshops).to contain_exactly(workshop)
    end

    it "keeps the free-text workshop title (minus the prefix) on the story and idea joins when there is no match" do
      import([ base_row("workshop" => "External title: Some Unlisted Workshop") ])

      expect(Story.sole.workshops).to be_empty
      expect(Story.sole.story_workshops.map(&:external_workshop_title)).to contain_exactly("Some Unlisted Workshop")
      expect(StoryIdea.sole.story_idea_workshops.map(&:external_workshop_title)).to contain_exactly("Some Unlisted Workshop")
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
      import([ base_row("organization_name" => "SKIP") ])

      expect(Organization.count).to eq(0)
      expect(Story.sole.organization).to be_nil
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
  end

  describe "tagging from the resolved columns" do
    let(:age_range) { create(:category_type, name: "AgeRange") }
    let(:emotional_theme) { create(:category_type, name: "EmotionalTheme") }

    it "tags sectors by name from the sectors column" do
      sector = create(:sector, name: "Substance Use/Recovery")
      import([ base_row("sectors" => "Substance Use/Recovery") ])

      expect(Story.sole.sectors).to include(sector)
    end

    it "keeps an unknown sector as a comment on the story" do
      import([ base_row("sectors" => "Imaginary Sector") ])

      expect(Story.sole.comments.pluck(:body)).to include(a_string_matching(/Imported sector not in portal: Imaginary Sector/))
    end

    it "tags categories by Type: Name from the categories column" do
      adults = create(:category, category_type: age_range, name: "Adults")
      grief = create(:category, category_type: emotional_theme, name: "Grief")
      import([ base_row("categories" => "AgeRange: Adults | EmotionalTheme: Grief") ])

      expect(Story.sole.categories).to include(adults, grief)
    end

    it "keeps an unknown category as a comment on the story" do
      import([ base_row("categories" => "AgeRange: Nope") ])

      expect(Story.sole.comments.pluck(:body)).to include(a_string_matching(/Imported category not in portal: AgeRange: Nope/))
    end

    # Ages belong to AgeRange; the StoryPopulation age twins are on their way out.
    it "reads an age filed under StoryPopulation as its AgeRange category" do
      story_population = create(:category_type, name: "StoryPopulation")
      twin = create(:category, category_type: story_population, name: "Teens_")
      teens = create(:category, category_type: age_range, name: "Teens")
      import([ base_row("categories" => "StoryPopulation: Teens") ])

      story = Story.sole
      expect(story.categories).to contain_exactly(teens)
      expect(story.categories).not_to include(twin)
      expect(story.comments.pluck(:body)).not_to include(a_string_matching(/category not in portal/))
    end

    it "stars an age-named primary story population on its AgeRange category" do
      teens = create(:category, category_type: age_range, name: "Teens")
      import([ base_row("categories" => "", "primary_story_population" => "StoryPopulation: Teens") ])

      story = Story.sole
      expect(story.categories).to contain_exactly(teens)
      expect(story.primary_category).to eq(teens)
    end

    it "flags the primary sector and primary story population on their join rows" do
      create(:sector, name: "Domestic Violence")
      story_population = create(:category_type, name: "StoryPopulation")
      create(:category, category_type: story_population, name: "Families")
      import([ base_row("sectors" => "Domestic Violence", "primary_sector" => "Domestic Violence",
                        "categories" => "StoryPopulation: Families",
                        "primary_story_population" => "StoryPopulation: Families") ])

      story = Story.sole
      expect(story.primary_sector.name).to eq("Domestic Violence")
      expect(story.primary_category.name).to eq("Families")
    end

    it "tags and flags a primary sector even when it's absent from the sectors list" do
      create(:sector, name: "Incarceration")
      import([ base_row("sectors" => "", "primary_sector" => "Incarceration") ])

      item = Story.sole.sectorable_items.find { |i| i.sector.name == "Incarceration" }
      expect(item.is_primary).to be(true)
    end

    it "stars a story's only sector and only audience when the row names no primary" do
      create(:sector, name: "Domestic Violence")
      adults = create(:category, category_type: age_range, name: "Adults")
      create(:category, category_type: emotional_theme, name: "Hope")
      import([ base_row("categories" => "AgeRange: Adults | EmotionalTheme: Hope") ])

      story = Story.sole
      expect(story.primary_sector.name).to eq("Domestic Violence")
      expect(story.primary_category).to eq(adults)
    end

    it "stars nothing when the row has several sectors or audiences and no primary" do
      create(:sector, name: "Domestic Violence")
      create(:sector, name: "Incarceration")
      create(:category, category_type: age_range, name: "Adults")
      create(:category, category_type: age_range, name: "Teens")
      import([ base_row("sectors" => "Domestic Violence | Incarceration", "categories" => "AgeRange: Adults | AgeRange: Teens") ])

      story = Story.sole
      expect(story.primary_sector).to be_nil
      expect(story.primary_category).to be_nil
    end

    it "ignores Other when deciding a story has only one sector" do
      create(:sector, name: "Domestic Violence")
      create(:sector, name: Sector::OTHER_SECTOR_NAME)
      import([ base_row("sectors" => "Domestic Violence | Other") ])

      expect(Story.sole.primary_sector.name).to eq("Domestic Violence")
    end

    it "stars Other when it's a story's only sector" do
      create(:sector, name: Sector::OTHER_SECTOR_NAME)
      import([ base_row("sectors" => "Other") ])

      expect(Story.sole.primary_sector.name).to eq(Sector::OTHER_SECTOR_NAME)
    end

    it "keeps the row's named primary over a sole-tag default" do
      create(:sector, name: "Domestic Violence")
      create(:sector, name: "Incarceration")
      import([ base_row("sectors" => "Domestic Violence", "primary_sector" => "Incarceration") ])

      expect(Story.sole.primary_sector.name).to eq("Incarceration")
    end

    it "keeps an unknown primary sector as a comment on the story" do
      import([ base_row("primary_sector" => "Imaginary Sector") ])

      expect(Story.sole.comments.pluck(:body)).to include(a_string_matching(/Imported sector not in portal: Imaginary Sector/))
    end

    describe "legacy terms recorded as tag aliases" do
      it "tags the sector an aliased sector name stands for" do
        education = create(:sector, name: "Education")
        create(:tag_alias, name: "Schools", aliasable: education, source: "story_share")
        import([ base_row("sectors" => "schools") ])

        story = Story.sole
        expect(story.sectors).to contain_exactly(education)
        expect(story.comments.pluck(:body)).not_to include(a_string_matching(/sector not in portal/))
      end

      it "tags every tag an alias names, whichever kind" do
        children = create(:category, category_type: age_range, name: "Children")
        teens = create(:category, category_type: age_range, name: "Teens")
        create(:tag_alias, name: "Youth", aliasable: children, source: "story_share")
        create(:tag_alias, name: "Youth", aliasable: teens, source: "story_share")
        import([ base_row("sectors" => "Youth") ])

        expect(Story.sole.categories).to contain_exactly(children, teens)
      end

      it "tags the category an aliased category name stands for" do
        grief = create(:category, category_type: emotional_theme, name: "Grief")
        create(:tag_alias, name: "Loss", aliasable: grief, source: "story_share")
        import([ base_row("categories" => "EmotionalTheme: Loss") ])

        story = Story.sole
        expect(story.categories).to contain_exactly(grief)
        expect(story.comments.pluck(:body)).not_to include(a_string_matching(/category not in portal/))
      end

      it "prefers a tag's own name over an alias spelled the same" do
        education = create(:sector, name: "Education")
        schools = create(:sector, name: "Schools")
        create(:tag_alias, name: "Schools", aliasable: education)
        import([ base_row("sectors" => "Schools") ])

        expect(Story.sole.sectors).to contain_exactly(schools)
      end

      it "drops a term recorded as naming no tag without flagging it" do
        create(:tag_alias, name: "Virtually", aliasable: nil, ignored: true)
        import([ base_row("sectors" => "Virtually") ])

        story = Story.sole
        expect(story.sectors).to be_empty
        expect(story.comments.pluck(:body)).not_to include(a_string_matching(/sector not in portal/))
      end

      it "flags the primary sector and story population an alias stands for" do
        education = create(:sector, name: "Education")
        families = create(:category, category_type: create(:category_type, name: "StoryPopulation"), name: "Families")
        create(:tag_alias, name: "Schools", aliasable: education, source: "story_share")
        create(:tag_alias, name: "Parents", aliasable: families, source: "story_share")
        import([ base_row("sectors" => "", "primary_sector" => "Schools",
                          "primary_story_population" => "StoryPopulation: Parents") ])

        story = Story.sole
        expect(story.primary_sector).to eq(education)
        expect(story.primary_category).to eq(families)
      end

      it "stars the first recorded tag when a primary alias names several" do
        children = create(:category, category_type: age_range, name: "Children")
        teens = create(:category, category_type: age_range, name: "Teens")
        create(:tag_alias, name: "C & T", aliasable: children)
        create(:tag_alias, name: "C & T", aliasable: teens)
        import([ base_row("primary_story_population" => "AgeRange: C & T") ])

        story = Story.sole
        expect(story.categories).to contain_exactly(children, teens)
        expect(story.primary_category).to eq(children)
      end
    end
  end

  describe "grants" do
    let!(:grant) { create(:grant, name: "Sample Legacy Scholarship") }

    it "creates the author's scholarship for a grant" do
      import([ base_row("grants" => "Sample Legacy Scholarship") ])

      author = Person.find_by(first_name: "Jamie", last_name: "Rivera")
      expect(Scholarship.where(recipient: author, grant: grant)).to exist
    end

    it "keeps the grant as a comment when there is no author to link" do
      import([ base_row("grants" => "Sample Legacy Scholarship",
                        "facilitator_name" => "Marguerite", "facilitator_last_name" => "") ])

      expect(Scholarship.count).to eq(0)
      expect(Story.sole.comments.pluck(:body)).to include(a_string_matching(/no author to link/))
    end

    it "keeps an unknown grant as a comment on the story" do
      import([ base_row("grants" => "Imaginary Grant") ])

      expect(Story.sole.comments.pluck(:body)).to include(a_string_matching(/Imported grant not in portal: Imaginary Grant/))
    end
  end

  describe "professional licenses" do
    it "attaches comma-separated licenses to the author" do
      import([ base_row("professional_licenses" => "LCSW, LMFT") ])

      author = Person.find_by(first_name: "Jamie", last_name: "Rivera")
      expect(author.professional_licenses.pluck(:kind)).to contain_exactly("LCSW", "LMFT")
    end

    it "keeps the licenses as a comment when there is no author" do
      import([ base_row("professional_licenses" => "LCSW",
                        "facilitator_name" => "Marguerite", "facilitator_last_name" => "") ])

      expect(ProfessionalLicense.count).to eq(0)
      expect(Story.sole.comments.pluck(:body)).to include(a_string_matching(/no author to attach.*LCSW/))
    end
  end

  describe "side effects" do
    it "creates a facilitator affiliation for a non-AWBW author" do
      import([ base_row ])

      author = Person.find_by(first_name: "Jamie", last_name: "Rivera")
      org = Organization.find_by("LOWER(name) = ?", "example family services")
      expect(Affiliation.where(person: author, organization: org, title: "Facilitator")).to exist
    end

    it "keeps the WordPress id as a comment on the story" do
      import([ base_row("wp_id" => "9003") ])

      expect(Story.sole.comments.pluck(:body)).to include(a_string_matching(/WordPress ID: 9003/))
    end

    it "preserves the publish date as created_at" do
      import([ base_row("published_date" => "2021-07-11 10:07:53") ])

      expect(Story.sole.created_at.to_date).to eq(Date.new(2021, 7, 11))
    end

    it "converts raw-newline paragraphs into HTML" do
      import([ base_row("content" => "Line one.\r\n\r\nLine two.") ])

      expect(Story.sole.rhino_body.to_plain_text).to match(/Line one\..*\n.*Line two/m)
    end

    it "marks the story featured when the featured column is yes" do
      import([ base_row("featured" => "yes") ])

      expect(Story.sole.featured).to be(true)
      expect(Story.sole.story_share_featured).to be(true)
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

    it "leaves an existing author's profile untouched" do
      author = create(:person, first_name: "Jamie", last_name: "Rivera",
                               display_name_preference: "full_name", anonymous_contributions: false)
      import([ base_row("name_display" => "first name only", "anonymous" => "anonymous") ], dry_run: true)

      expect(author.reload).to have_attributes(anonymous_contributions: false,
                                               display_name_preference: "full_name")
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

    it "surfaces window type, featured, grants, licenses, and unmatched taxonomy" do
      result = import([ base_row("window_type" => "Children", "featured" => "yes",
                                 "grants" => "Some Grant", "professional_licenses" => "LCSW",
                                 "sectors" => "Imaginary Sector") ], dry_run: true)

      preview = result.previews.sole
      expect(preview.window_type).to eq("Children")
      expect(preview.featured).to be(true)
      expect(preview.grants).to include("Some Grant")
      expect(preview.licenses).to include("LCSW")
      expect(preview.missing_tags).to include("Imaginary Sector")
    end
  end

  describe "image import" do
    let(:image_row) do
      base_row(
        "image_urls" => "https://ex.com/cover.jpg|https://ex.com/two.jpg",
        "image_alt_titles" => "Cover alt|Second alt"
      )
    end

    it "enqueues a StoryAssetImportJob with the URLs and parallel titles" do
      import([ image_row ])

      expect(StoryAssetImportJob).to have_been_enqueued
        .with(Story.sole, [ "https://ex.com/cover.jpg", "https://ex.com/two.jpg" ],
              titles: [ "Cover alt", "Second alt" ])
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
