# spec/models/comment_spec.rb
require 'rails_helper'

RSpec.describe Comment, type: :model do
  describe 'associations' do
    it { should belong_to(:commentable) }
  end

  describe 'validations' do
    it 'is valid with valid attributes' do
      user = create(:user)
      comment = build(:comment, commentable: user, body: "Test comment")
      expect(comment).to be_valid
    end

    it 'is invalid without a body' do
      user = create(:user)
      comment = build(:comment, commentable: user, body: nil)
      expect(comment).not_to be_valid
    end
  end

  describe 'polymorphic association' do
    let!(:user) { create(:user) }
    let!(:person) { create(:person) }

    it 'can be associated with a User' do
      comment = create(:comment, commentable: user, body: "User comment")
      expect(comment.commentable).to eq(user)
      expect(user.comments).to include(comment)
    end

    it 'can be associated with a Person' do
      comment = create(:comment, commentable: person, body: "Person comment")
      expect(comment.commentable).to eq(person)
      expect(person.comments).to include(comment)
    end

    it 'can be associated with an EventRegistration' do
      event_registration = create(:event_registration)
      comment = create(:comment, commentable: event_registration, body: "Registration comment")
      expect(comment.commentable).to eq(event_registration)
      expect(event_registration.comments).to include(comment)
    end
  end

  describe 'scopes' do
    let!(:user) { create(:user) }
    let!(:old_comment) { create(:comment, commentable: user, body: "Old comment", created_at: 2.days.ago) }
    let!(:new_comment) { create(:comment, commentable: user, body: "New comment", created_at: 1.day.ago) }

    it 'orders comments by created_at descending with newest_first scope' do
      expect(user.comments.first).to eq(new_comment)
      expect(user.comments.last).to eq(old_comment)
    end
  end
end
