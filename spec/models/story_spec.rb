require 'rails_helper'

RSpec.describe Story, type: :model do
  describe "#author_credit" do
    let(:user) { create(:user, :with_person) }
    let(:person) { user.person }
    let(:story) { create(:story, created_by: user) }

    context "when author_credit_preference is full name" do
      it "returns the person's full name" do
        story.update!(author_credit_preference: AuthorCreditable::AUTHOR_CREDIT_PREFERENCES[0])
        expect(story.author_credit).to eq(person.full_name)
      end
    end

    context "when author_credit_preference is first name only" do
      it "returns the person's first name" do
        story.update!(author_credit_preference: AuthorCreditable::AUTHOR_CREDIT_PREFERENCES[1])
        expect(story.author_credit).to eq(person.first_name)
      end
    end

    context "when author_credit_preference is anonymous" do
      it "returns Anonymous" do
        story.update!(author_credit_preference: AuthorCreditable::AUTHOR_CREDIT_PREFERENCES[2])
        expect(story.author_credit).to eq("Anonymous")
      end
    end

    context "when author_credit_preference is nil" do
      it "falls back to the person's display name preference" do
        expect(story.author_credit_preference).to be_nil
        expect(story.author_credit).to eq(person.name)
      end
    end

    context "when user has no person" do
      let(:user) { create(:user, person: nil) }

      it "returns Anonymous" do
        expect(story.author_credit).to eq("Anonymous")
      end
    end
  end
end
