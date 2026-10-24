require "rails_helper"

RSpec.describe NotificationServices::NotifyAuthors do
  let(:author) { create(:person, email: "author@example.com") }
  let(:co_author) { create(:person, email: "co-author@example.com") }

  def notices(record)
    Notification.where(noticeable: record).pluck(:kind, :recipient_email, :person_id)
  end

  it "notifies the author and co-author" do
    story = create(:story, author: author, co_author: co_author)

    described_class.call(record: story, kind: :story_promoted)

    expect(notices(story)).to contain_exactly(
      [ "story_promoted", "author@example.com", author.id ],
      [ "story_promoted", "co-author@example.com", co_author.id ]
    )
  end

  it "notifies an anonymously credited author" do
    story = create(:story, author: author, author_credit_preference: "anonymous")

    described_class.call(record: story, kind: :story_promoted)

    expect(notices(story)).to contain_exactly([ "story_promoted", "author@example.com", author.id ])
  end

  it "notifies nobody when no author is credited" do
    story = create(:story, author: nil)

    expect { described_class.call(record: story, kind: :story_promoted) }.not_to change(Notification, :count)
  end
end
