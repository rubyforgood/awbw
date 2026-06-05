RSpec.shared_examples "author_creditable" do |factory:|
  describe "#author_credit" do
    let(:person) { create(:person) }
    # Story/StoryIdea credit a direct author association; other includers derive
    # the credited person from the creating user.
    let(:has_author_association) { described_class.reflect_on_association(:author).present? }
    let(:record) do
      if has_author_association
        create(factory, author: person)
      else
        create(factory, created_by: create(:user, person: person))
      end
    end

    context "when author_credit_preference is full_name" do
      it "returns the person's full name" do
        record.update!(author_credit_preference: "full_name")
        expect(record.author_credit).to eq(person.full_name)
      end
    end

    context "when author_credit_preference is first_name_last_initial" do
      it "returns first name and last initial with period" do
        record.update!(author_credit_preference: "first_name_last_initial")
        expect(record.author_credit).to eq("#{person.first_name} #{person.last_name.first}.")
      end
    end

    context "when author_credit_preference is first_name_only" do
      it "returns the person's first name" do
        record.update!(author_credit_preference: "first_name_only")
        expect(record.author_credit).to eq(person.first_name)
      end
    end

    context "when author_credit_preference is last_name_only" do
      it "returns the person's last name" do
        record.update!(author_credit_preference: "last_name_only")
        expect(record.author_credit).to eq(person.last_name)
      end
    end

    context "when author_credit_preference is anonymous" do
      it "returns Anonymous" do
        record.update!(author_credit_preference: "anonymous")
        expect(record.author_credit).to eq("Anonymous")
      end
    end

    context "when author_credit_preference is nil", unless: described_class.validators_on(:author_credit_preference).any? { |v| v.is_a?(ActiveModel::Validations::PresenceValidator) } do
      it "falls back to the person's display name" do
        record.update!(author_credit_preference: nil)
        expect(record.author_credit).to eq(person.name)
      end
    end

    context "when there is no credited person" do
      it "returns Anonymous" do
        if has_author_association
          record.update!(author: nil)
        else
          record.update!(created_by: create(:user, person: nil))
        end
        expect(record.author_credit).to eq("Anonymous")
      end
    end
  end
end
