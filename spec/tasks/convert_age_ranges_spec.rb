require "rails_helper"
require "rake"

RSpec.describe "data:convert_age_ranges" do
  before(:all) do
    Rails.application.load_tasks
  end

  before do
    Rake::Task["data:convert_age_ranges"].reenable

    # The has_many :comments association is added in a separate PR.
    # Define it here so the rake task can run in isolation.
    unless Workshop.reflect_on_association(:comments)
      Workshop.has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy
    end
  end

  let!(:age_range_type) { create(:category_type, name: "AgeRange") }
  let!(:cat_3_5)   { create(:category, name: "3-5", category_type: age_range_type) }
  let!(:cat_6_12)  { create(:category, name: "6-12", category_type: age_range_type) }
  let!(:cat_13_17) { create(:category, name: "13-17", category_type: age_range_type) }
  let!(:cat_18)    { create(:category, name: "18+", category_type: age_range_type) }
  let!(:cat_mixed) { create(:category, name: "Mixed-age groups", category_type: age_range_type) }
  let!(:cat_family) { create(:category, name: "Family Windows", category_type: age_range_type) }

  def run_task
    Rake::Task["data:convert_age_ranges"].invoke
  end

  def age_range_category_names(workshop)
    workshop.reload.categorizable_items
            .joins(category: :category_type)
            .where(category_types: { name: "AgeRange" })
            .map { |ci| ci.category.name }
            .sort
  end

  # --- Numeric ranges ---

  describe "numeric range classification" do
    {
      "3-5" => [ "3-5" ],
      "6-12" => [ "6-12" ],
      "13-17" => [ "13-17" ],
      "5-12" => [ "3-5", "6-12" ],
      "6-14" => [ "13-17", "6-12" ],
      "3-99" => [ "13-17", "18+", "3-5", "6-12" ],
      "3-18" => [ "13-17", "18+", "3-5", "6-12" ],
      "10-15" => [ "13-17", "6-12" ],
      "3 - 5" => [ "3-5" ],
      "6–12" => [ "6-12" ],
      "3 to 5" => [ "3-5" ]
    }.each do |input, expected|
      it "maps '#{input}' to #{expected.join(', ')}" do
        workshop = create(:workshop, age_range: input)
        run_task
        expect(age_range_category_names(workshop)).to eq expected
      end
    end
  end

  # --- Near-boundary tolerance (±1 year) ---

  describe "near-boundary tolerance" do
    {
      "2-4" => [ "3-5" ],
      "2-5" => [ "3-5" ],
      "3-6" => [ "3-5", "6-12" ],
      "4-6" => [ "3-5", "6-12" ],
      "5-7" => [ "3-5", "6-12" ],
      "7-11" => [ "6-12" ],
      "7-12" => [ "6-12" ],
      "5-13" => [ "13-17", "3-5", "6-12" ],
      "12-14" => [ "13-17", "6-12" ],
      "12-17" => [ "13-17", "6-12" ],
      "14-19" => [ "13-17", "18+" ],
      "17-25" => [ "13-17", "18+" ]
    }.each do |input, expected|
      it "maps '#{input}' to #{expected.join(', ')}" do
        workshop = create(:workshop, age_range: input)
        run_task
        expect(age_range_category_names(workshop)).to eq expected
      end
    end
  end

  # --- Open-ended ranges ---

  describe "open-ended range classification" do
    {
      "5 and up" => [ "13-17", "18+", "3-5", "6-12" ],
      "5 & up" => [ "13-17", "18+", "3-5", "6-12" ],
      "5 and above" => [ "13-17", "18+", "3-5", "6-12" ],
      "5 and older" => [ "13-17", "18+", "3-5", "6-12" ],
      "18+" => [ "18+" ],
      "18 and up" => [ "18+" ],
      "6+" => [ "13-17", "18+", "6-12" ],
      "13+" => [ "13-17", "18+" ],
      "5 year old on up" => [ "13-17", "18+", "3-5", "6-12" ],
      "5up" => [ "13-17", "18+", "3-5", "6-12" ]
    }.each do |input, expected|
      it "maps '#{input}' to #{expected.join(', ')}" do
        workshop = create(:workshop, age_range: input)
        run_task
        expect(age_range_category_names(workshop)).to eq expected
      end
    end
  end

  # --- Standalone ages ---

  describe "standalone age classification" do
    {
      "5 years old" => [ "3-5" ],
      "10 years old" => [ "6-12" ],
      "15 year olds" => [ "13-17" ],
      "3" => [ "3-5" ],
      "8" => [ "6-12" ],
      "14" => [ "13-17" ]
    }.each do |input, expected|
      it "maps '#{input}' to #{expected.join(', ')}" do
        workshop = create(:workshop, age_range: input)
        run_task
        expect(age_range_category_names(workshop)).to eq expected
      end
    end
  end

  # --- Keyword classification ---

  describe "keyword classification" do
    {
      "adult" => [ "18+" ],
      "Adult Women" => [ "18+" ],
      "women" => [ "18+" ],
      "teen" => [ "13-17" ],
      "tweens" => [ "13-17" ],
      "children" => [ "3-5", "6-12" ],
      "elementary" => [ "3-5", "6-12" ],
      "school age" => [ "3-5", "6-12" ],
      "preschool" => [ "3-5" ],
      "pre-school" => [ "3-5" ],
      "pre-k" => [ "3-5" ],
      "kinder" => [ "3-5" ],
      "youth" => [ "13-17", "6-12" ],
      "young people" => [ "13-17", "6-12" ],
      "all ages" => [ "Mixed-age groups" ],
      "any age" => [ "Mixed-age groups" ],
      "mixed" => [ "Mixed-age groups" ],
      "family" => [ "Mixed-age groups" ]
    }.each do |input, expected|
      it "maps '#{input}' to #{expected.join(', ')}" do
        workshop = create(:workshop, age_range: input)
        run_task
        expect(age_range_category_names(workshop)).to eq expected
      end
    end
  end

  # --- Spanish classification ---

  describe "Spanish classification" do
    {
      "5 en adelante" => [ "13-17", "18+", "3-5", "6-12" ],
      "18 y más" => [ "18+" ],
      "18 y mas" => [ "18+" ],
      "18 o más" => [ "18+" ],
      "6 para arriba" => [ "13-17", "18+", "6-12" ],
      "10 años en adelante" => [ "13-17", "18+", "6-12" ],
      "todas las edades" => [ "Mixed-age groups" ],
      "jóvenes" => [ "13-17", "6-12" ]
    }.each do |input, expected|
      it "maps '#{input}' to #{expected.join(', ')}" do
        workshop = create(:workshop, age_range: nil, age_range_spanish: input)
        run_task
        expect(age_range_category_names(workshop)).to eq expected
      end
    end

    it "strips HTML tags from age_range_spanish" do
      workshop = create(:workshop, age_range: nil, age_range_spanish: "<div>18 y más</div>")
      run_task
      expect(age_range_category_names(workshop)).to eq [ "18+" ]
    end

    it "decodes HTML entities" do
      workshop = create(:workshop, age_range: nil, age_range_spanish: "ni&ntilde;os")
      run_task
      # "niños" doesn't match a keyword, so it should be unmatched
      expect(age_range_category_names(workshop)).to eq []
    end
  end

  # --- Union of English and Spanish ---

  describe "union of English and Spanish" do
    it "combines categories from both fields" do
      workshop = create(:workshop, age_range: "teen", age_range_spanish: "<p>18 y más</p>")
      run_task
      expect(age_range_category_names(workshop)).to eq [ "13-17", "18+" ]
    end

    it "deduplicates categories found in both fields" do
      workshop = create(:workshop, age_range: "18+", age_range_spanish: "18 y más")
      run_task
      expect(age_range_category_names(workshop)).to eq [ "18+" ]
      expect(workshop.reload.categorizable_items.count).to eq 1
    end
  end

  # --- Skipped values ---

  describe "skipped values" do
    %w[0 x n/a].each do |val|
      it "skips '#{val}'" do
        workshop = create(:workshop, age_range: val)
        run_task
        expect(age_range_category_names(workshop)).to eq []
      end
    end

    it "skips nil/blank values" do
      workshop = create(:workshop, age_range: nil, age_range_spanish: nil)
      run_task
      expect(age_range_category_names(workshop)).to eq []
    end

    it "skips empty string" do
      workshop = create(:workshop, age_range: "", age_range_spanish: "")
      run_task
      expect(age_range_category_names(workshop)).to eq []
    end
  end

  # --- Idempotency ---

  describe "idempotency" do
    it "does not duplicate categories on re-run" do
      workshop = create(:workshop, age_range: "6-12")
      run_task
      Rake::Task["data:convert_age_ranges"].reenable
      run_task
      expect(age_range_category_names(workshop)).to eq [ "6-12" ]
      expect(workshop.reload.categorizable_items.count).to eq 1
    end

    it "does not duplicate comments on re-run" do
      workshop = create(:workshop, age_range: "6-12")
      run_task
      Rake::Task["data:convert_age_ranges"].reenable
      run_task
      expect(workshop.reload.comments.count).to eq 1
    end
  end

  # --- Nilling exact matches ---

  describe "nilling exact matches" do
    it "nils age_range when it exactly matches a category name" do
      workshop = create(:workshop, age_range: "18+")
      run_task
      expect(workshop.reload.age_range).to be_nil
    end

    it "nils age_range case-insensitively" do
      workshop = create(:workshop, age_range: "Mixed-Age Groups")
      run_task
      expect(workshop.reload.age_range).to be_nil
    end

    it "nils age_range_spanish when it exactly matches a category name" do
      workshop = create(:workshop, age_range: nil, age_range_spanish: "18+")
      run_task
      expect(workshop.reload.age_range_spanish).to be_nil
    end

    it "does not nil age_range when value does not match a category name" do
      workshop = create(:workshop, age_range: "5-12")
      run_task
      expect(workshop.reload.age_range).to eq "5-12"
    end
  end

  # --- Comments ---

  describe "comments" do
    it "creates an auto-applied comment with [AGE_RANGE_DATA] tag" do
      workshop = create(:workshop, age_range: "6-12")
      run_task
      comment = workshop.reload.comments.first
      expect(comment).to be_present
      expect(comment.body).to include("[AGE_RANGE_DATA]")
      expect(comment.body).to include("Auto-applied age range categories: 6-12")
      expect(comment.body).to include("age_range: '6-12'")
    end

    it "lists multiple auto-applied categories in comment" do
      workshop = create(:workshop, age_range: "5-14")
      run_task
      comment = workshop.reload.comments.first
      expect(comment.body).to include("3-5")
      expect(comment.body).to include("6-12")
      expect(comment.body).to include("13-17")
    end

    it "creates an unmatched comment with [AGE_RANGE_DATA] tag" do
      workshop = create(:workshop, age_range: "potato")
      run_task
      comment = workshop.reload.comments.first
      expect(comment).to be_present
      expect(comment.body).to include("[AGE_RANGE_DATA]")
      expect(comment.body).to include("Could not auto-apply")
      expect(comment.body).to include("age_range: 'potato'")
    end

    it "includes Spanish source in comment when present" do
      workshop = create(:workshop, age_range: nil, age_range_spanish: "18 y más")
      run_task
      comment = workshop.reload.comments.first
      expect(comment.body).to include("age_range_spanish:")
    end

    it "does not create a comment when already tagged" do
      workshop = create(:workshop, age_range: "6-12")
      workshop.categorizable_items.create!(category: cat_6_12)
      run_task
      expect(workshop.reload.comments.count).to eq 0
    end
  end
end
