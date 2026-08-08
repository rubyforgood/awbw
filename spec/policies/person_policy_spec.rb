require "rails_helper"

RSpec.describe PersonPolicy, type: :policy do
  let(:admin_user) { build_stubbed(:user, :admin) }
  let(:regular_user) { build_stubbed(:user) }
  let(:owner_user) { build_stubbed(:user) }

  let(:searchable_person) { build_stubbed(:person, profile_is_searchable: true, user: build_stubbed(:user)) }
  let(:non_searchable_person) { build_stubbed(:person, profile_is_searchable: false, user: build_stubbed(:user)) }
  let(:owned_person) { build_stubbed(:person, user: owner_user) }

  def policy_for(record: nil, user:)
    described_class.new(record, user: user)
  end

  describe "#own_membership?" do
    subject { policy_for(record: owned_person, user: user) }

    context "with the person's own user" do
      let(:user) { owner_user }

      it { is_expected.to be_allowed_to(:own_membership?) }
    end

    context "with an admin looking at someone else" do
      let(:user) { admin_user }

      it { is_expected.not_to be_allowed_to(:own_membership?) }
    end

    context "with another signed-in user" do
      let(:user) { regular_user }

      it { is_expected.not_to be_allowed_to(:own_membership?) }
    end

    context "when membership is disabled" do
      let(:user) { owner_user }

      before { allow(Membership).to receive(:enabled?).and_return(false) }

      it { is_expected.not_to be_allowed_to(:own_membership?) }
    end
  end

  describe "#index?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:index?) }
    end

    context "with regular user" do
      subject { policy_for(user: regular_user) }

      it { is_expected.not_to be_allowed_to(:index?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.not_to be_allowed_to(:index?) }
    end
  end

  describe "#show?" do
    context "with admin user" do
      subject { policy_for(record: non_searchable_person, user: admin_user) }

      it { is_expected.to be_allowed_to(:show?) }
    end

    context "with owner" do
      subject { policy_for(record: owned_person, user: owner_user) }

      it { is_expected.to be_allowed_to(:show?) }
    end

    context "with regular user and searchable person" do
      subject { policy_for(record: searchable_person, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end

    context "with regular user and non-searchable person" do
      subject { policy_for(record: non_searchable_person, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end

    context "with no user" do
      subject { policy_for(record: searchable_person, user: nil) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end
  end

  describe "#workshop_logs?" do
    context "with admin user" do
      subject { policy_for(record: owned_person, user: admin_user) }

      it { is_expected.to be_allowed_to(:workshop_logs?) }
    end

    context "with owner" do
      subject { policy_for(record: owned_person, user: owner_user) }

      it { is_expected.to be_allowed_to(:workshop_logs?) }
    end

    context "with regular user who is not the owner" do
      subject { policy_for(record: searchable_person, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:workshop_logs?) }
    end

    context "with no user" do
      subject { policy_for(record: searchable_person, user: nil) }

      it { is_expected.not_to be_allowed_to(:workshop_logs?) }
    end
  end

  describe "#show_email_change?" do
    context "with admin user" do
      subject { policy_for(record: owned_person, user: admin_user) }

      it { is_expected.to be_allowed_to(:show_email_change?) }
    end

    context "with owner" do
      subject { policy_for(record: owned_person, user: owner_user) }

      it { is_expected.to be_allowed_to(:show_email_change?) }
    end

    context "with regular user who is not the owner" do
      subject { policy_for(record: searchable_person, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:show_email_change?) }
    end

    context "with no user" do
      subject { policy_for(record: searchable_person, user: nil) }

      it { is_expected.not_to be_allowed_to(:show_email_change?) }
    end
  end

  describe "#edit?" do
    context "with admin user" do
      subject { policy_for(record: searchable_person, user: admin_user) }

      it { is_expected.to be_allowed_to(:edit?) }
    end

    context "with owner" do
      subject { policy_for(record: owned_person, user: owner_user) }

      it { is_expected.not_to be_allowed_to(:edit?) }
    end

    context "with regular user who is not the owner" do
      subject { policy_for(record: searchable_person, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:edit?) }
    end
  end

  describe "#destroy?" do
    context "when person has authored stories" do
      let(:admin) { create(:user, :admin) }
      let(:person) { create(:person, user: nil) }

      before do
        create(:story, author: person)
      end

      it "is not allowed" do
        policy = policy_for(record: person, user: admin)

        expect(policy).not_to be_allowed_to(:destroy?)
      end
    end

    context "when person has authored workshop variations" do
      let(:admin) { create(:user, :admin) }
      let(:person) { create(:person, user: nil) }

      before do
        create(:workshop_variation, author: person)
      end

      it "is not allowed" do
        policy = policy_for(record: person, user: admin)

        expect(policy).not_to be_allowed_to(:destroy?)
      end
    end

    context "when person has authored workshops" do
      let(:admin) { create(:user, :admin) }
      let(:person) { create(:person, user: nil) }

      before do
        create(:workshop, author: person)
      end

      it "is not allowed" do
        policy = policy_for(record: person, user: admin)

        expect(policy).not_to be_allowed_to(:destroy?)
      end
    end

    context "when person has authored community news" do
      let(:admin) { create(:user, :admin) }
      let(:person) { create(:person, user: nil) }

      before do
        create(:community_news, author: person)
      end

      it "is not allowed" do
        policy = policy_for(record: person, user: admin)

        expect(policy).not_to be_allowed_to(:destroy?)
      end
    end

    context "when person has authored resources" do
      let(:admin) { create(:user, :admin) }
      let(:person) { create(:person, user: nil) }

      before do
        create(:resource, author: person)
      end

      it "is not allowed" do
        policy = policy_for(record: person, user: admin)

        expect(policy).not_to be_allowed_to(:destroy?)
      end
    end
  end

  describe "relation_scope" do
    context "with admin user" do
      let(:policy) { policy_for(record: Person, user: admin_user) }

      it "returns all people" do
        scope = policy.apply_scope(Person.all, type: :active_record_relation)
        expect(scope).to eq(Person.all)
      end
    end

    context "with regular user" do
      let(:policy) { policy_for(record: Person, user: regular_user) }

      it "filters to searchable people with active affiliations and unlocked users" do
        scope = policy.apply_scope(Person.all, type: :active_record_relation)
        sql = scope.to_sql
        expect(sql).to include('`people`.`profile_is_searchable` = TRUE')
        expect(sql).to include('INNER JOIN `affiliations`')
        expect(sql).to include('`affiliations`.`inactive` = FALSE')
        expect(sql).to include('`users`.`locked_at` IS NULL')
      end

      it "excludes people whose user account is locked" do
        regular = create(:user)
        searchable = create(:person, profile_is_searchable: true)
        create(:affiliation, person: searchable, inactive: false, end_date: nil)
        locked = create(:person, profile_is_searchable: true, user: create(:user, :locked))
        create(:affiliation, person: locked, inactive: false, end_date: nil)
        unlinked = create(:person, profile_is_searchable: true, user: nil)
        create(:affiliation, person: unlinked, inactive: false, end_date: nil)

        policy = described_class.new(Person, user: regular)
        scope = policy.apply_scope(Person.all, type: :active_record_relation)

        expect(scope).to include(searchable, unlinked)
        expect(scope).not_to include(locked)
      end
    end
  end
end
