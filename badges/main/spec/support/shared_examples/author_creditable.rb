RSpec.shared_examples "author_creditable" do |factory:|
  describe "#author_credit" do
    let(:author_user) { create(:user, :with_person) }
    let(:person) { author_user.person }
    let(:record) { create(factory, created_by: author_user) }

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

    context "when user has no person" do
      it "returns Anonymous" do
        user_without_person = create(:user, person: nil)
        record.update!(created_by: user_without_person)
        expect(record.author_credit).to eq("Anonymous")
      end
    end
  end
end
