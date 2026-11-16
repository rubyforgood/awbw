require "rails_helper"

# "Publicly visible" only takes effect once a record is published (the
# visibility hint says so, and the publicly_visible scope chains published), so
# a direct link to an unpublished record stays closed to non-admins.
RSpec.describe "Publicly visible requires published", type: :policy do
  {
    CommunityNewsPolicy => :community_news,
    EventPolicy => :event,
    FaqPolicy => :faq,
    ResourcePolicy => :resource,
    StoryPolicy => :story,
    StorySharePolicy => :story,
    VideoRecordingPolicy => :video_recording,
    WorkshopPolicy => :workshop,
    WorkshopVariationPolicy => :workshop_variation
  }.each do |policy_class, factory|
    describe policy_class.name do
      let(:user) { build_stubbed(:user) }

      define_method(:policy) { |record, user| policy_class.new(record, user: user) }

      it "lets a guest open a published, publicly visible record" do
        record = build_stubbed(factory, published: true, publicly_visible: true)
        expect(policy(record, nil)).to be_allowed_to(:show?)
      end

      it "keeps an unpublished, publicly visible record closed to guests" do
        record = build_stubbed(factory, published: false, publicly_visible: true)
        expect(policy(record, nil)).not_to be_allowed_to(:show?)
      end

      it "keeps an unpublished, publicly visible record closed to logged-in users" do
        record = build_stubbed(factory, published: false, publicly_visible: true)
        expect(policy(record, user)).not_to be_allowed_to(:show?)
      end
    end
  end
end
