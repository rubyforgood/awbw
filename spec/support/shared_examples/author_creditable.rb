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

    if described_class.require_author_credit_preference?
      context "when the preference is unset (required)" do
        it "is invalid without a credit preference" do
          record.author_credit_preference = nil
          expect(record).not_to be_valid
          expect(record.errors[:author_credit_preference]).to be_present
        end

        it "does not default new records" do
          expect(described_class.new.author_credit_preference).to be_blank
        end
      end
    else
      context "when the preference is unset (defaulted)" do
        it "defaults new records to full_name" do
          expect(described_class.new.author_credit_preference).to eq("full_name")
        end

        it "treats a blank preference as full_name at read time" do
          record.author_credit_preference = nil
          expect(record.author_credit).to eq(person.full_name)
        end

        it "normalizes a blank preference to full_name on save (no backfill)" do
          record.update!(author_credit_preference: nil)
          expect(record.reload.author_credit_preference).to eq("full_name")
        end
      end
    end

    context "when the preference is not one of the allowed values" do
      it "is invalid" do
        record.author_credit_preference = "sideways"
        expect(record).not_to be_valid
        expect(record.errors[:author_credit_preference]).to be_present
      end
    end

    context "when there is no credited person" do
      it "falls back to the model's missing_author_label" do
        user_without_person = create(:user, person: nil)
        record.update!(created_by: user_without_person)
        expect(record.author_credit).to eq(record.missing_author_label)
        expect(record.missing_author_label).to be_present
      end
    end
  end

  describe ".by_credited_person_name" do
    let(:author_user) { create(:user, :with_person) }
    let!(:record) { create(factory, created_by: author_user) }

    it "matches the creating user's person by name" do
      author_user.person.update!(first_name: "Zephyrine", last_name: "Quixotel")
      expect(described_class.by_credited_person_name("Zephyrine")).to include(record)
      expect(described_class.by_credited_person_name("Quixotel")).to include(record)
    end

    it "does not match an unrelated name" do
      author_user.person.update!(first_name: "Zephyrine", last_name: "Quixotel")
      expect(described_class.by_credited_person_name("Nonexistententry")).not_to include(record)
    end
  end

  describe ".order_by_author" do
    it "runs without error in both directions" do
      create(factory)
      expect { described_class.order_by_author("asc").to_a }.not_to raise_error
      expect { described_class.order_by_author("desc").to_a }.not_to raise_error
    end
  end
end
