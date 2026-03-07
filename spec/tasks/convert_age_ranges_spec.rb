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

  describe "numeric range classification" do
    it "maps '5-12' to 3-5, 6-12" do
      workshop = create(:workshop, age_range: "5-12")
      run_task
      expect(age_range_category_names(workshop)).to eq ["3-5", "6-12"]
    end

    it "maps '6-14' to 6-12, 13-17" do
      workshop = create(:workshop, age_range: "6-14")
      run_task
      expect(age_range_category_names(workshop)).to eq ["13-17", "6-12"]
    end

    it "maps '3-99' to all age buckets" do
      workshop = create(:workshop, age_range: "3-99")
      run_task
      expect(age_range_category_names(workshop)).to eq ["13-17", "18+", "3-5", "6-12"]
    end
  end

  describe "open-ended range classification" do
    it "maps '5 and up' across all buckets" do
      workshop = create(:workshop, age_range: "5 and up")
      run_task
      expect(age_range_category_names(workshop)).to eq ["13-17", "18+", "3-5", "6-12"]
    end

    it "maps '18+' to 18+" do
      workshop = create(:workshop, age_range: "18+")
      run_task
      expect(age_range_category_names(workshop)).to eq ["18+"]
    end
  end

  describe "keyword classification" do
    it "maps 'adult' to 18+" do
      workshop = create(:workshop, age_range: "adult")
      run_task
      expect(age_range_category_names(workshop)).to eq ["18+"]
    end

    it "maps 'teen' to 13-17" do
      workshop = create(:workshop, age_range: "teen")
      run_task
      expect(age_range_category_names(workshop)).to eq ["13-17"]
    end

    it "maps 'children' to 3-5, 6-12" do
      workshop = create(:workshop, age_range: "children")
      run_task
      expect(age_range_category_names(workshop)).to eq ["3-5", "6-12"]
    end

    it "maps 'all ages' to Mixed-age groups" do
      workshop = create(:workshop, age_range: "all ages")
      run_task
      expect(age_range_category_names(workshop)).to eq ["Mixed-age groups"]
    end
  end

  describe "Spanish classification" do
    it "maps '5 en adelante' from age_range_spanish" do
      workshop = create(:workshop, age_range: nil, age_range_spanish: "5 en adelante")
      run_task
      expect(age_range_category_names(workshop)).to eq ["13-17", "18+", "3-5", "6-12"]
    end

    it "maps HTML-wrapped Spanish value" do
      workshop = create(:workshop, age_range: nil, age_range_spanish: "<div>18 y más</div>")
      run_task
      expect(age_range_category_names(workshop)).to eq ["18+"]
    end
  end

  describe "union of English and Spanish" do
    it "combines categories from both fields" do
      workshop = create(:workshop, age_range: "teen", age_range_spanish: "<p>18 y más</p>")
      run_task
      expect(age_range_category_names(workshop)).to eq ["13-17", "18+"]
    end
  end

  describe "skipped values" do
    it "skips '0', 'x', 'n/a'" do
      %w[0 x n/a].each do |val|
        workshop = create(:workshop, age_range: val)
        run_task
        Rake::Task["data:convert_age_ranges"].reenable
        expect(age_range_category_names(workshop)).to eq([]), "Expected '#{val}' to be skipped"
      end
    end

    it "skips nil/blank values" do
      workshop = create(:workshop, age_range: nil, age_range_spanish: nil)
      run_task
      expect(age_range_category_names(workshop)).to eq []
    end
  end

  describe "idempotency" do
    it "does not duplicate categories on re-run" do
      workshop = create(:workshop, age_range: "6-12")
      run_task
      Rake::Task["data:convert_age_ranges"].reenable
      run_task
      expect(age_range_category_names(workshop)).to eq ["6-12"]
    end
  end

  describe "nilling exact matches" do
    it "nils age_range when it exactly matches a category name" do
      workshop = create(:workshop, age_range: "18+")
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

    it "creates an unmatched comment with [AGE_RANGE_DATA] tag" do
      workshop = create(:workshop, age_range: "potato")
      run_task
      comment = workshop.reload.comments.first
      expect(comment).to be_present
      expect(comment.body).to include("[AGE_RANGE_DATA]")
      expect(comment.body).to include("Could not auto-apply")
      expect(comment.body).to include("age_range: 'potato'")
    end

    it "does not create a comment when already tagged" do
      workshop = create(:workshop, age_range: "6-12")
      workshop.categorizable_items.create!(category: cat_6_12)
      run_task
      expect(workshop.reload.comments.count).to eq 0
    end
  end
end
