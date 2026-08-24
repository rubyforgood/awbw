RSpec.shared_examples "author_creditable" do |factory:, org_credited:, credits_creator: false, anonymous_when_unattributed: false|
  model = factory.to_s.camelize.constantize
  names_author = model.column_names.include?("author_id")
  # What a record with nobody left to credit falls to: a generic label ("AWBW Staff"
  # for org-produced content, otherwise the facilitator label), or "Anonymous" on the
  # models that say so. A `credits_creator` model only gets here once the creator is
  # gone or hidden too — otherwise it credits them by name.
  unattributed_label = if anonymous_when_unattributed
    "Anonymous"
  else
    org_credited ? "AWBW Staff" : "AWBW Facilitator"
  end

  # Only a model with an author_id credits a person; without one, a record always
  # falls to the generic label no matter who entered it.
  def credited_record(factory, user, person, names_author, **attrs)
    attrs[:author] = person if names_author
    create(factory, created_by: user, **attrs)
  end

  describe "#author_credit" do
    let(:author_user) { create(:user, :with_person) }
    let(:person) { author_user.person }
    let(:record) { credited_record(factory, author_user, person, names_author) }

    context "when the preference is not one of the allowed values" do
      it "is invalid" do
        record.author_credit_preference = "sideways"
        expect(record).not_to be_valid
        expect(record.errors[:author_credit_preference]).to be_present
      end
    end

    if names_author
      context "with no stored preference, following the profile" do
        before { record.update!(author_credit_preference: nil) }

        it "returns the full name for full_name" do
          person.update!(display_name_preference: "full_name")
          expect(record.author_credit).to eq(person.full_name)
        end

        it "returns first name and last initial for first_name_last_initial" do
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
      end

      context "with its own stored preference, which the profile still outranks" do
        # The stored value is the submitter's request, recorded for an admin to apply
        # to the profile — it doesn't change what renders on its own.
        it "still formats by the profile" do
          person.update!(display_name_preference: "full_name")
          record.update!(author_credit_preference: "first_name_only")
          expect(record.author_credit).to eq(person.full_name)
        end

        it "reports the divergence so an admin can resolve it" do
          record.update!(author_credit_preference: "last_name_only")
          person.update!(display_name_preference: "full_name")
          expect(record.author_credit).to eq(person.full_name)
          expect(record.author_credit_diverged?).to be(true)
        end
      end

      context "when the profile marks contributions anonymous" do
        before { person.update!(anonymous_contributions: true) }

        # A suppressed explicit-author credit reads the unattributed label rather
        # than the profile name — the org label, or "Anonymous" for creator-legacy.
        it "returns the unattributed label regardless of the name format" do
          person.update!(display_name_preference: "full_name")
          expect(record.author_credit).to eq(unattributed_label)
        end

        it "does not link the credit to a profile" do
          expect(record.author_credit_person).to be_nil
        end
      end

      context "when the record itself was submitted anonymously" do
        before { record.update!(author_credit_preference: "anonymous") }

        it "stays suppressed even though the profile says otherwise" do
          person.update!(display_name_preference: "full_name", anonymous_contributions: false)
          expect(record.author_credit).to eq(unattributed_label)
        end

        it "does not link the credit to a profile" do
          expect(record.author_credit_person).to be_nil
        end
      end

      context "when the author is removed" do
        before { record.update!(author: nil, author_credit_preference: nil) }

        it "uses the unattributed label as the missing-author label" do
          expect(record.missing_author_label).to eq(unattributed_label)
        end

        if credits_creator
          it "credits the creator's person by name instead of the generic label" do
            expect(record.author_credit).to eq(person.name)
          end
        else
          it "falls back to the generic label rather than crediting the creator" do
            expect(record.author_credit).to eq(unattributed_label)
          end
        end

        if credits_creator
          it "formats the creator credit by their own profile preference" do
            person.update!(display_name_preference: "first_name_only")
            expect(record.author_credit).to eq(person.first_name)
          end

          it "links the credit to the creator's profile" do
            expect(record.author_credit_person).to eq(person)
          end

          it "suppresses the credit when the creator opted out of being named" do
            person.update!(anonymous_contributions: true)
            expect(record.author_credit).to eq(unattributed_label)
            expect(record.author_credit_person).to be_nil
          end
        end
      end
    else
      context "on an idea record, which names no author" do
        it "always credits the generic label, never the creator" do
          person.update!(display_name_preference: "full_name")
          expect(record.author_credit).to eq(unattributed_label)
        end

        it "does not link the credit to a profile" do
          expect(record.author_credit_person).to be_nil
        end
      end
    end
  end

  if names_author
    describe "the consent snapshot" do
      let(:author_user) { create(:user, :with_person) }
      let(:person) { author_user.person }

      it "records the profile's preference on create" do
        person.update!(display_name_preference: "first_name_only")
        record = credited_record(factory, author_user, person, names_author, author_credit_preference: nil)
        expect(record.reload.author_credit_preference).to eq("first_name_only")
      end

      it "records anonymous when the profile suppresses credits" do
        person.update!(anonymous_contributions: true)
        record = credited_record(factory, author_user, person, names_author, author_credit_preference: nil)
        expect(record.reload.author_credit_preference).to eq("anonymous")
      end

      it "does not overwrite a preference carried forward from an idea" do
        record = credited_record(factory, author_user, person, names_author, author_credit_preference: "last_name_only")
        expect(record.reload.author_credit_preference).to eq("last_name_only")
      end

      it "normalizes a blank preference to nil so the record follows the profile" do
        record = credited_record(factory, author_user, person, names_author, author_credit_preference: "full_name")
        record.update!(author_credit_preference: "")
        expect(record.reload.author_credit_preference).to be_nil
      end

      it "reports no divergence when the snapshot matches the profile" do
        person.update!(display_name_preference: "full_name")
        record = credited_record(factory, author_user, person, names_author, author_credit_preference: nil)
        expect(record.author_credit_diverged?).to be(false)
      end
    end
  end

  describe ".credited_openly" do
    let(:author_user) { create(:user, :with_person) }
    let!(:record) { create(factory, created_by: author_user, author_credit_preference: "full_name") }

    it "includes a record whose stored preference is a name format" do
      expect(model.credited_openly).to include(record)
    end

    it "excludes a record submitted anonymously" do
      record.update!(author_credit_preference: "anonymous")
      expect(model.credited_openly).not_to include(record)
    end

    it "includes a record with no stored preference, which just follows the profile" do
      model.where(id: record.id).update_all(author_credit_preference: nil)
      expect(model.credited_openly).to include(record)
    end
  end

  if names_author
    describe ".credited_to_person" do
      let(:person) { create(:person) }
      let(:their_user) { create(:user, person: person) }

      it "includes records they explicitly authored" do
        record = create(factory, author: person, created_by: create(:user))
        expect(model.credited_to_person(person)).to include(record)
      end

      it "includes unauthored records their user created (legacy fallback)" do
        record = create(factory, author: nil, created_by: their_user)
        expect(model.credited_to_person(person)).to include(record)
      end

      it "excludes records authored by someone else, even if their user created them" do
        record = create(factory, author: create(:person), created_by: their_user)
        expect(model.credited_to_person(person)).not_to include(record)
      end
    end
  end

  describe ".by_credited_person_name" do
    if names_author
      let(:author_user) { create(:user, :with_person) }
      let(:person) { author_user.person }
      let!(:record) { credited_record(factory, author_user, person, names_author, author_credit_preference: nil) }

      before { person.update!(first_name: "Zephyrine", last_name: "Quixotel") }

      it "matches the credited person by name" do
        expect(model.by_credited_person_name("Zephyrine")).to include(record)
        expect(model.by_credited_person_name("Quixotel")).to include(record)
      end

      it "does not match an unrelated name" do
        expect(model.by_credited_person_name("Nonexistententry")).not_to include(record)
      end

      it "matches nothing when the profile marks contributions anonymous" do
        person.update!(anonymous_contributions: true)
        expect(model.by_credited_person_name("Zephyrine")).not_to include(record)
        expect(model.by_credited_person_name("Quixotel")).not_to include(record)
      end

      it "matches nothing when the record was submitted anonymously" do
        record.update!(author_credit_preference: "anonymous")
        expect(model.by_credited_person_name("Zephyrine")).not_to include(record)
      end

      it "does not match the last name when the profile shows the first name only" do
        person.update!(display_name_preference: "first_name_only")
        expect(model.by_credited_person_name("Zephyrine")).to include(record)
        expect(model.by_credited_person_name("Quixotel")).not_to include(record)
      end

      it "does not match the first name when the profile shows the last name only" do
        person.update!(display_name_preference: "last_name_only")
        expect(model.by_credited_person_name("Quixotel")).to include(record)
        expect(model.by_credited_person_name("Zephyrine")).not_to include(record)
      end

      it "matches only the initial for first_name_last_initial" do
        person.update!(display_name_preference: "first_name_last_initial")
        expect(model.by_credited_person_name("Zephyrine")).to include(record)
        expect(model.by_credited_person_name("ZephyrineQ")).to include(record)
        expect(model.by_credited_person_name("Quixotel")).not_to include(record)
      end

      # The stored request doesn't gate search either — only the profile does.
      it "still matches the full name when the record asked for first_name_only" do
        record.update!(author_credit_preference: "first_name_only")
        expect(model.by_credited_person_name("Quixotel")).to include(record)
      end

      if credits_creator
        context "when no author is named, so the creator is credited" do
          before { record.update!(author: nil) }

          it "matches the creator's person by name" do
            expect(model.by_credited_person_name("Zephyrine")).to include(record)
            expect(model.by_credited_person_name("Quixotel")).to include(record)
          end

          it "honors the creator's own display preference" do
            person.update!(display_name_preference: "first_name_only")
            expect(model.by_credited_person_name("Quixotel")).not_to include(record)
          end

          it "matches nothing when the creator opted out of being named" do
            person.update!(anonymous_contributions: true)
            expect(model.by_credited_person_name("Zephyrine")).not_to include(record)
          end
        end

        it "does not reach the creator once someone else is the named author" do
          record.update!(author: create(:person, first_name: "Corvid", last_name: "Talbotson"))

          expect(model.by_credited_person_name("Zephyrine")).not_to include(record)
          expect(model.by_credited_person_name("Corvid")).to include(record)
        end
      end
    else
      it "matches nobody, since an idea names no author" do
        create(factory)
        expect(model.by_credited_person_name("anything")).to be_empty
      end
    end
  end

  describe ".order_by_author" do
    it "runs without error in both directions" do
      create(factory)
      expect { model.order_by_author("asc").to_a }.not_to raise_error
      expect { model.order_by_author("desc").to_a }.not_to raise_error
    end
  end
end
