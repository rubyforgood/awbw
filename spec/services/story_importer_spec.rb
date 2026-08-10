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
      facilitator_name facilitator_last_name home_top_featured_story Date
    ]
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
      "showhide_the_name" => "display_full_name"
    }.merge(overrides)
  end

  def import(rows, **opts)
    described_class.new(csv_path: csv_file(rows), import_user: import_user, **opts).call
  end

  it "creates a story idea for every row" do
    result = import([ base_row, base_row("ID" => "2", "Title" => "Second", "organization_name" => "New Leaf") ])

    expect(result.ideas_created).to eq(2)
    expect(StoryIdea.count).to eq(2)
  end

  it "creates a connected published story for published rows" do
    import([ base_row ])

    story = Story.sole
    expect(story.published).to be(true)
    expect(story.publicly_visible).to be(true)
    expect(story.story_idea).to eq(StoryIdea.sole)
    expect(story.title).to eq("A story of healing")
  end

  it "does not create a story for draft rows" do
    result = import([ base_row("Status" => "draft") ])

    expect(result.ideas_created).to eq(1)
    expect(result.stories_created).to eq(0)
    expect(Story.count).to eq(0)
  end

  it "maps showhide_the_name to author_credit_preference" do
    import([ base_row("showhide_the_name" => "hide_full_name") ])

    expect(StoryIdea.sole.author_credit_preference).to eq("anonymous")
  end

  it "decodes HTML entities in the organization name and reuses the org" do
    import([
      base_row("ID" => "1", "organization_name" => "Smith &amp; Co"),
      base_row("ID" => "2", "Title" => "Another", "organization_name" => "Smith & Co")
    ])

    expect(Organization.where("LOWER(name) = ?", "smith & co").count).to eq(1)
  end

  it "derives windows type from audience tags" do
    import([
      base_row("ID" => "1", "Title" => "Kids", "Tags" => "Children"),
      base_row("ID" => "2", "Title" => "Grown", "Tags" => "Adults"),
      base_row("ID" => "3", "Title" => "Both", "Tags" => "Families")
    ])

    expect(StoryIdea.find_by(title: "Kids").windows_type).to eq(children_wt)
    expect(StoryIdea.find_by(title: "Grown").windows_type).to eq(adult_wt)
    expect(StoryIdea.find_by(title: "Both").windows_type).to eq(combined_wt)
  end

  it "derives windows type from pipe-delimited multi-audience tags" do
    import([
      base_row("ID" => "1", "Title" => "Kids only", "Tags" => "children|teens"),
      base_row("ID" => "2", "Title" => "Mixed ages", "Tags" => "adults|children"),
      base_row("ID" => "3", "Title" => "Only grown", "Tags" => "adults|colleagues")
    ])

    expect(StoryIdea.find_by(title: "Kids only").windows_type).to eq(children_wt)
    expect(StoryIdea.find_by(title: "Mixed ages").windows_type).to eq(combined_wt)
    expect(StoryIdea.find_by(title: "Only grown").windows_type).to eq(adult_wt)
  end

  it "tags a matching sector via the category mapping" do
    sector = create(:sector, name: "Substance Use/Recovery")
    import([ base_row("Categories" => "Substance Abuse Recovery") ])

    expect(StoryIdea.sole.sectors).to include(sector)
    expect(Story.sole.sectors).to include(sector)
  end

  it "warns when a category has no mapping and no matching sector" do
    result = import([ base_row("Categories" => "Facilitator Spotlights") ])

    expect(result.warnings).to include(a_string_matching(/no Sector match/))
    expect(StoryIdea.sole.sectors).to be_empty
  end

  it "resolves and warns about unmatched sectors even on a dry run" do
    result = import([ base_row("Categories" => "Facilitator Spotlights") ], dry_run: true)

    expect(result.warnings).to include(a_string_matching(/no Sector match/))
  end

  it "warns about unmapped fields rather than dropping them" do
    result = import([ base_row("state" => "California", "facilitator_name" => "Eydie") ])

    expect(result.warnings).to include(a_string_matching(/unmapped state "California"/))
    expect(result.warnings).to include(a_string_matching(/unmapped facilitator "Eydie"/))
  end

  it "skips a published story whose title is already taken but still keeps the idea" do
    create(:story, title: "A story of healing")
    result = import([ base_row ])

    expect(result.ideas_created).to eq(1)
    expect(result.stories_created).to eq(0)
    expect(result.warnings).to include(a_string_matching(/title already taken/))
  end

  it "is idempotent for story ideas across re-runs" do
    rows = [ base_row("Status" => "draft") ]
    import(rows)
    result = import(rows)

    expect(result.ideas_created).to eq(0)
    expect(result.skipped).to include(a_string_matching(/already exists/))
    expect(StoryIdea.count).to eq(1)
  end

  it "skips rows with a blank title" do
    result = import([ base_row("Title" => "") ])

    expect(result.skipped).to include(a_string_matching(/blank title/))
    expect(StoryIdea.count).to eq(0)
  end

  describe "dry run" do
    it "writes nothing but reports what would be created" do
      result = import([ base_row ], dry_run: true)

      expect(StoryIdea.count).to eq(0)
      expect(Story.count).to eq(0)
      expect(result.ideas_created).to eq(1)
      expect(result.stories_created).to eq(1)
    end
  end
end
