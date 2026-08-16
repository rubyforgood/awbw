RSpec.shared_examples "author_creditable" do |factory:|
  # A model with an author_id must name its author — the credit never falls back to
  # whoever entered the record. The idea models have no author_id, so their creator
  # is the only credit path they have.
  def credits_creator?
    !described_class.column_names.include?("author_id")
  end

  def credited_record(factory, user, person, **attrs)
    attrs[:author] = person unless credits_creator?
    create(factory, created_by: user, **attrs)
  end

  describe "#author_credit" do
    let(:author_user) { create(:user, :with_person) }
    let(:person) { author_user.person }
    let(:record) { credited_record(factory, author_user, person) }

    context "when the profile formats the name" do
      it "returns the full name for full_name" do
        person.update!(display_name_preference: "full_name")
        expect(record.author_credit).to eq(person.full_name)
      end

      it "returns first name and last initial with period for first_name_last_initial" do
        person.update!(display_name_preference: "first_name_last_initial")
        expect(record.author_credit).to eq("#{person.first_name} #{person.last_name.first}.")
      end

      it "returns the first name for first_name_only" do
        person.update!(display_name_preference: "first_name_only")
        expect(record.author_credit).to eq(person.first_name)
      end

      it "returns the last name for last_name_only" do
        person.update!(display_name_preference: "last_name_only")
        expect(record.author_credit).to eq(person.last_name)
      end

      it "falls back to the full name when the profile has no preference" do
        person.update!(display_name_preference: nil)
        expect(record.author_credit).to eq(person.full_name)
      end
    end

    context "when the profile marks contributions anonymous" do
      before { person.update!(anonymous_contributions: true) }

      # Behind a login, so a suppressed credit names the org rather than saying
      # "Anonymous", which would read as being about the reader's access.
      it "returns the generic label regardless of the name format" do
        person.update!(display_name_preference: "full_name")
        expect(record.author_credit).to eq("AWBW Facilitator")
      end

      it "does not link the credit to a profile" do
        expect(record.author_credit_person).to be_nil
      end
    end

    context "when the record itself was submitted anonymously" do
      before { record.update!(author_credit_preference: "anonymous") }

      it "stays suppressed even though the profile says otherwise" do
        person.update!(display_name_preference: "full_name", anonymous_contributions: false)
        expect(record.author_credit).to eq("AWBW Facilitator")
      end

      it "does not link the credit to a profile" do
        expect(record.author_credit_person).to be_nil
      end
    end

    context "when the stored preference is a name format" do
      it "is ignored in favor of the profile" do
        record.update!(author_credit_preference: "first_name_only")
        person.update!(display_name_preference: "full_name")
        expect(record.author_credit).to eq(person.full_name)
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
      # The portal is behind a login, so an unattributed credit names the org's
      # facilitators rather than hiding behind "Anonymous".
      it "falls back to AWBW Facilitator" do
        record.update!(created_by: create(:user, person: nil))
        record.update!(author: nil) unless credits_creator?
        expect(record.missing_author_label).to eq("AWBW Facilitator")
        expect(record.author_credit).to eq("AWBW Facilitator")
      end
    end
  end

  describe "the consent snapshot" do
    let(:author_user) { create(:user, :with_person) }
    let(:person) { author_user.person }

    it "records the profile's preference on create" do
      person.update!(display_name_preference: "first_name_only")
      record = credited_record(factory, author_user, person, author_credit_preference: nil)
      expect(record.reload.author_credit_preference).to eq("first_name_only")
    end

    it "records anonymous when the profile suppresses credits" do
      person.update!(anonymous_contributions: true)
      record = credited_record(factory, author_user, person, author_credit_preference: nil)
      expect(record.reload.author_credit_preference).to eq("anonymous")
    end

    it "does not overwrite a preference carried forward from an idea" do
      record = credited_record(factory, author_user, person, author_credit_preference: "last_name_only")
      expect(record.reload.author_credit_preference).to eq("last_name_only")
    end

    it "normalizes a blank preference to nil so the record just follows the profile" do
      record = credited_record(factory, author_user, person, author_credit_preference: "full_name")
      record.update!(author_credit_preference: "")
      expect(record.reload.author_credit_preference).to be_nil
    end

    it "is left alone when the profile later changes, and reports the divergence" do
      person.update!(display_name_preference: "first_name_only")
      record = credited_record(factory, author_user, person, author_credit_preference: nil)

      person.update!(display_name_preference: "full_name")

      expect(record.reload.author_credit_preference).to eq("first_name_only")
      expect(record.author_credit_diverged?).to be(true)
      expect(record.author_credit).to eq(person.full_name)
    end

    it "reports no divergence when the snapshot matches the profile" do
      person.update!(display_name_preference: "full_name")
      record = credited_record(factory, author_user, person, author_credit_preference: nil)
      expect(record.author_credit_diverged?).to be(false)
    end
  end

  describe ".credited_openly" do
    let(:author_user) { create(:user, :with_person) }
    let!(:record) { create(factory, created_by: author_user, author_credit_preference: "full_name") }

    it "includes a record whose snapshot is a name format" do
      expect(described_class.credited_openly).to include(record)
    end

    it "excludes a record submitted anonymously" do
      record.update!(author_credit_preference: "anonymous")
      expect(described_class.credited_openly).not_to include(record)
    end

    it "includes a record with no snapshot, which just follows the profile" do
      # The un-backfilled state of every pre-callback row, and what clearing the
      # snapshot on the divergences page writes back.
      described_class.where(id: record.id).update_all(author_credit_preference: nil)
      expect(described_class.credited_openly).to include(record)
    end
  end

  describe ".by_credited_person_name" do
    let(:author_user) { create(:user, :with_person) }
    let(:person) { author_user.person }
    let!(:record) { credited_record(factory, author_user, person) }

    before { person.update!(first_name: "Zephyrine", last_name: "Quixotel") }

    it "matches the credited person by name" do
      expect(described_class.by_credited_person_name("Zephyrine")).to include(record)
      expect(described_class.by_credited_person_name("Quixotel")).to include(record)
    end

    it "does not match an unrelated name" do
      expect(described_class.by_credited_person_name("Nonexistententry")).not_to include(record)
    end

    it "matches nothing when the profile marks contributions anonymous" do
      person.update!(anonymous_contributions: true)
      expect(described_class.by_credited_person_name("Zephyrine")).not_to include(record)
      expect(described_class.by_credited_person_name("Quixotel")).not_to include(record)
    end

    it "matches nothing when the record was submitted anonymously" do
      record.update!(author_credit_preference: "anonymous")
      expect(described_class.by_credited_person_name("Zephyrine")).not_to include(record)
    end

    it "does not match on last name when only the first name is shown" do
      person.update!(display_name_preference: "first_name_only")
      expect(described_class.by_credited_person_name("Zephyrine")).to include(record)
      expect(described_class.by_credited_person_name("Quixotel")).not_to include(record)
    end

    it "does not match on first name when only the last name is shown" do
      person.update!(display_name_preference: "last_name_only")
      expect(described_class.by_credited_person_name("Quixotel")).to include(record)
      expect(described_class.by_credited_person_name("Zephyrine")).not_to include(record)
    end

    it "matches only the initial when the last name is reduced to one" do
      person.update!(display_name_preference: "first_name_last_initial")
      expect(described_class.by_credited_person_name("Zephyrine")).to include(record)
      expect(described_class.by_credited_person_name("ZephyrineQ")).to include(record)
      expect(described_class.by_credited_person_name("Quixotel")).not_to include(record)
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
