require "rails_helper"

RSpec.describe StoryServices::NotifyIdeaAuthorOfPublication do
  let(:author) { create(:user) }
  let(:story_idea) { create(:story_idea, created_by: author, updated_by: author) }

  context "when a published story is promoted from a story idea" do
    let(:story) do
      create(:story, :published, story_idea: story_idea, created_by: author, updated_by: author)
    end

    it "creates a story_published notification addressed to the idea author" do
      expect {
        described_class.call(story)
      }.to change { Notification.where(kind: "story_published").count }.by(1)

      notification = Notification.where(kind: "story_published").last
      expect(notification.recipient_email).to eq(author.email)
      expect(notification.recipient_role).to eq("person")
      expect(notification.noticeable).to eq(story)
    end

    it "does not notify twice for the same story" do
      described_class.call(story)

      expect {
        described_class.call(story)
      }.not_to change { Notification.where(kind: "story_published").count }
    end
  end

  context "when the story is not promoted from a story idea" do
    let(:story) { create(:story, :published, story_idea: nil) }

    it "does not create a notification" do
      expect { described_class.call(story) }.not_to change { Notification.count }
    end
  end

  context "when the story is not published" do
    let(:story) do
      create(:story, :unpublished, story_idea: story_idea, created_by: author, updated_by: author)
    end

    it "does not create a notification" do
      expect { described_class.call(story) }.not_to change { Notification.count }
    end
  end
end
