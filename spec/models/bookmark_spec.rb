# frozen_string_literal: true

require "rails_helper"

RSpec.describe(Bookmark) do
  # pending "add some examples to (or delete) #{__FILE__}"

  describe "associations" do
    it { is_expected.to(belong_to(:user)) }
    it { is_expected.to(belong_to(:bookmarkable)) } # Polymorphic
    it { is_expected.to(have_many(:bookmark_annotations).dependent(:destroy)) }
  end

  it "is valid with valid attributes" do
    user = build_stubbed(:user)
    workshop = build_stubbed(:workshop)
    bookmark = build(:bookmark, user: user, bookmarkable: workshop)
    expect(bookmark).to(be_valid)
  end
end
