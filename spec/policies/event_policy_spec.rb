require "rails_helper"

RSpec.describe EventPolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, :admin }
  let(:regular_user) { build_stubbed :user }
  let(:published_event) { build_stubbed :event, :published }
  let(:public_event) { build_stubbed :event, publicly_visible: true  }
  let(:unpublished_event) { build_stubbed :event, :unpublished }
  let(:open_registration_event) { build_stubbed :event, registration_close_date: 1.day.from_now }
  let(:closed_registration_event) { build_stubbed :event, registration_close_date: 1.day.ago }

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

      it { is_expected.to be_allowed_to(:index?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.to be_allowed_to(:index?) }
    end
  end

  describe "#show?" do
    context "when event is visible" do
      context "with admin user" do
        subject { policy_for(record: published_event, user: admin_user) }

        it { is_expected.to be_allowed_to(:show?) }
      end

      context "with regular user" do
        subject { policy_for(record: published_event, user: regular_user) }

        it { is_expected.to be_allowed_to(:show?) }
      end

      context "with no user" do
        subject { policy_for(record: public_event, user: nil) }

        it { is_expected.to be_allowed_to(:show?) }
      end
    end

    context "when event is not visible" do
      context "with admin user" do
        subject { policy_for(record: unpublished_event, user: admin_user) }

        it { is_expected.to be_allowed_to(:show?) }
      end

      context "with regular user" do
        subject { policy_for(record: unpublished_event, user: regular_user) }

        it { is_expected.not_to be_allowed_to(:show?) }
      end

      context "with no user" do
        subject { policy_for(record: unpublished_event, user: nil) }

        it { is_expected.not_to be_allowed_to(:show?) }
      end
    end
  end

  describe "#manage?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:manage?) }
    end

    context "with regular user" do
      subject { policy_for(user: regular_user) }

      it { is_expected.not_to be_allowed_to(:manage?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.not_to be_allowed_to(:manage?) }
    end
  end

  describe "aliases to :manage?" do
    let(:policy) { policy_for(user: admin_user) }

    describe "#new?" do
      it "is an alias of :manage? authorization rule" do
        expect(:new?).to be_an_alias_of(policy, :manage?)
      end
    end

    describe "#create?" do
      it "is an alias of :manage? authorization rule" do
        expect(:create?).to be_an_alias_of(policy, :manage?)
      end
    end
  end

  describe "#edit?" do
    let(:owned_event) { build_stubbed :event, created_by: regular_user }

    context "with admin user" do
      subject { policy_for(record: published_event, user: admin_user) }

      it { is_expected.to be_allowed_to(:edit?) }
    end

    context "with owner" do
      subject { policy_for(record: owned_event, user: regular_user) }

      it { is_expected.to be_allowed_to(:edit?) }
    end

    context "with non-owner regular user" do
      subject { policy_for(record: published_event, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:edit?) }
    end
  end

  describe "#preview?" do
    it "is an alias of :edit? authorization rule" do
      policy = policy_for(record: published_event, user: admin_user)
      expect(:preview?).to be_an_alias_of(policy, :edit?)
    end
  end

  describe "#update?" do
    let(:owned_event) { build_stubbed :event, created_by: regular_user }

    context "with admin user" do
      subject { policy_for(record: published_event, user: admin_user) }

      it { is_expected.to be_allowed_to(:update?) }
    end

    context "with owner" do
      subject { policy_for(record: owned_event, user: regular_user) }

      it { is_expected.to be_allowed_to(:update?) }
    end

    context "with non-owner regular user" do
      subject { policy_for(record: published_event, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:update?) }
    end
  end

  describe "relation_scope" do
    context "with admin user" do
      let(:policy) { policy_for(record: Event, user: admin_user) }

      it "returns all events" do
        scope = policy.apply_scope(Event.all, type: :active_record_relation)
        expect(scope).to eq(Event.all)
      end
    end

    context "with regular user" do
      let(:policy) { policy_for(record: Event, user: regular_user) }

      it "returns only visible events with open registration" do
        scope = policy.apply_scope(Event.all, type: :active_record_relation)
        expect(scope.to_sql).to include('`events`.`published` = TRUE')
        expect(scope.to_sql).to include('registration_close_date IS NULL OR registration_close_date >=')
        expect(scope.to_sql).to include('LEFT OUTER JOIN `event_registrations`')
      end
    end

    context "with no user" do
      let(:policy) { policy_for(record: Event, user: nil) }

      it "returns only visible events with open registration" do
        scope = policy.apply_scope(Event.all, type: :active_record_relation)
        expect(scope.to_sql).to include('`events`.`published` = TRUE')
        expect(scope.to_sql).to include('registration_close_date IS NULL OR registration_close_date >=')
        expect(scope.to_sql).not_to include('LEFT OUTER JOIN `registrants`')
      end
    end
  end
end
