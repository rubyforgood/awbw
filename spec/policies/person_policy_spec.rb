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

  describe "#edit?" do
    context "with admin user" do
      subject { policy_for(record: searchable_person, user: admin_user) }

      it { is_expected.to be_allowed_to(:edit?) }
    end

    context "with owner" do
      subject { policy_for(record: owned_person, user: owner_user) }

      it { is_expected.to be_allowed_to(:edit?) }
    end

    context "with regular user who is not the owner" do
      subject { policy_for(record: searchable_person, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:edit?) }
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

      it "filters to searchable people with active affiliations" do
        scope = policy.apply_scope(Person.all, type: :active_record_relation)
        expect(scope.to_sql).to include('`people`.`profile_is_searchable` = TRUE')
        expect(scope.to_sql).to include('INNER JOIN `affiliations`')
        expect(scope.to_sql).to include('`affiliations`.`inactive` = FALSE')
      end
    end
  end
end
