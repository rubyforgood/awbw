require "rails_helper"

RSpec.describe UserStampable, type: :model do
  # Banner carries both stamp columns and a required belongs_to :created_by.
  let(:creator) { create(:user) }
  let(:editor)  { create(:user) }

  def with_current(user, &block)
    Current.set(user: user, &block)
  end

  describe "on create" do
    it "stamps updated_by from Current.user" do
      banner = with_current(creator) { Banner.create!(content: "Hi", show: true, created_by: creator) }

      expect(banner.updated_by).to eq(creator)
    end

    it "satisfies a required belongs_to :updated_by without an explicit assignment" do
      expect { with_current(creator) { Banner.create!(content: "Hi", show: true, created_by: creator) } }
        .not_to raise_error
    end

    it "leaves created_by to the caller" do
      banner = with_current(creator) { Banner.create!(content: "Hi", show: true, created_by: editor) }

      expect(banner.created_by).to eq(editor)
    end
  end

  describe "on update" do
    let!(:banner) { with_current(creator) { Banner.create!(content: "Hi", show: true, created_by: creator) } }

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
  end

  describe "without a Current.user" do
    it "leaves the stamp columns to whatever the caller set" do
      banner = with_current(nil) do
        Banner.create!(content: "Hi", show: true, created_by: creator, updated_by: creator)
      end

      expect(banner.updated_by).to eq(creator)
    end
  end
end
