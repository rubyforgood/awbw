require "rails_helper"

RSpec.describe UserStampable, type: :model do
  # Banner carries both stamp columns, each a required belongs_to.
  let(:creator) { create(:user) }
  let(:editor)  { create(:user) }

  def with_current(user, &block)
    Current.set(user: user, &block)
  end

  describe "on create" do
    it "stamps created_by and updated_by from Current.user" do
      banner = with_current(creator) { Banner.create!(content: "Hi", show: true) }

      expect(banner.created_by).to eq(creator)
      expect(banner.updated_by).to eq(creator)
    end

    it "satisfies required belongs_to stamps without an explicit assignment" do
      expect { with_current(creator) { Banner.create!(content: "Hi", show: true) } }
        .not_to raise_error
    end

    it "forces created_by to Current.user, ignoring a mass-assigned value" do
      banner = with_current(creator) { Banner.create!(content: "Hi", show: true, created_by: editor) }

      expect(banner.created_by).to eq(creator)
    end
  end

  describe "on update" do
    let!(:banner) { with_current(creator) { Banner.create!(content: "Hi", show: true) } }

    it "stamps updated_by with the current editor without touching created_by" do
      with_current(editor) { banner.update!(content: "Edited") }

      expect(banner.reload.created_by).to eq(creator)
      expect(banner.updated_by).to eq(editor)
    end

    it "respects an explicitly assigned updated_by" do
      assigned = create(:user)
      with_current(editor) { banner.update!(content: "Edited", updated_by: assigned) }

      expect(banner.reload.updated_by).to eq(assigned)
    end

    it "does not re-stamp on a save that changes nothing" do
      with_current(editor) { banner.save! }

      expect(banner.reload.updated_by).to eq(creator)
    end

    it "never backfills created_by on update — only stamps it at create" do
      tag = StaffTag.create!(name: "Legacy tag")
      expect(tag.created_by).to be_nil

      with_current(editor) { tag.update!(name: "Edited tag") }

      expect(tag.reload.created_by).to be_nil
      expect(tag.updated_by).to eq(editor)
    end
  end

  describe "without a Current.user" do
    it "leaves the stamp columns to whatever the caller set" do
      banner = with_current(nil) do
        Banner.create!(content: "Hi", show: true, created_by: creator, updated_by: creator)
      end

      expect(banner.created_by).to eq(creator)
      expect(banner.updated_by).to eq(creator)
    end
  end

  describe "#update_columns_stamped" do
    let(:banner) { with_current(creator) { Banner.create!(content: "Hi", show: true) } }

    it "writes the columns with updated_at and updated_by from Current.user, skipping validations" do
      banner.update_columns(updated_at: 1.day.ago)

      with_current(editor) { banner.update_columns_stamped(content: "") }

      expect(banner.reload).to have_attributes(content: "", updated_by: editor)
      expect(banner.updated_at).to be_within(1.minute).of(Time.current)
    end

    it "credits the user it's given" do
      banner.update_columns_stamped(show: false, user: editor)

      expect(banner.reload.updated_by).to eq(editor)
    end

    it "still bumps updated_at with no one to credit, leaving updated_by alone" do
      banner.update_columns(updated_at: 1.day.ago)

      banner.update_columns_stamped(show: false)

      expect(banner.reload.updated_by).to eq(creator)
      expect(banner.updated_at).to be_within(1.minute).of(Time.current)
    end
  end
end
