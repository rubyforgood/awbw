require "rails_helper"

RSpec.describe EventPolicy, type: :policy do
  let(:admin_user) { build_stubbed :user, :admin }
  let(:regular_user) { build_stubbed :user }
  let(:published_event) { build_stubbed :event, :published }
  let(:public_event) { build_stubbed :event, publicly_visible: true  }
  let(:unpublished_event) { build_stubbed :event, :unpublished }
  let(:ended_event) { build_stubbed :event, :published, :ended }
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

  describe "#search?" do
    context "with admin user" do
      subject { policy_for(user: admin_user) }

      it { is_expected.to be_allowed_to(:search?) }
    end

    context "with regular user" do
      subject { policy_for(user: regular_user) }

      it { is_expected.not_to be_allowed_to(:search?) }
    end

    context "with no user" do
      subject { policy_for(user: nil) }

      it { is_expected.not_to be_allowed_to(:search?) }
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

    context "when event has ended" do
      context "with admin user" do
        subject { policy_for(record: ended_event, user: admin_user) }

        it { is_expected.to be_allowed_to(:show?) }
      end

      context "with registered user" do
        subject { policy_for(record: ended_event, user: regular_user) }

        before { allow(ended_event).to receive(:actively_registered?).with(regular_user.person).and_return(true) }

        it { is_expected.to be_allowed_to(:show?) }
      end

      context "with unregistered user" do
        subject { policy_for(record: ended_event, user: regular_user) }

        before { allow(ended_event).to receive(:actively_registered?).with(regular_user.person).and_return(false) }

        it { is_expected.not_to be_allowed_to(:show?) }
      end

      context "with no user" do
        subject { policy_for(record: ended_event, user: nil) }

        it { is_expected.not_to be_allowed_to(:show?) }
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

  describe "#dashboard?" do
    let(:owned_event) { build_stubbed :event, created_by: regular_user }

    context "with admin user" do
      subject { policy_for(record: published_event, user: admin_user) }

      it { is_expected.to be_allowed_to(:dashboard?) }
    end

    context "with owner" do
      subject { policy_for(record: owned_event, user: regular_user) }

      it { is_expected.to be_allowed_to(:dashboard?) }
    end

    context "with non-owner regular user" do
      subject { policy_for(record: published_event, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:dashboard?) }
    end

    context "with no user" do
      subject { policy_for(record: published_event, user: nil) }

      it { is_expected.not_to be_allowed_to(:dashboard?) }
    end
  end

  describe "#form_submissions?" do
    let(:owned_event) { build_stubbed :event, created_by: regular_user }

    context "with admin user" do
      subject { policy_for(record: published_event, user: admin_user) }

      it { is_expected.to be_allowed_to(:form_submissions?) }
    end

    context "with owner" do
      subject { policy_for(record: owned_event, user: regular_user) }

      it { is_expected.to be_allowed_to(:form_submissions?) }
    end

    context "with non-owner regular user" do
      subject { policy_for(record: published_event, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:form_submissions?) }
    end

    context "with no user" do
      subject { policy_for(record: published_event, user: nil) }

      it { is_expected.not_to be_allowed_to(:form_submissions?) }
    end
  end

  describe "#registrants?" do
    let(:owned_event) { build_stubbed :event, created_by: regular_user }

    context "with admin user" do
      subject { policy_for(record: published_event, user: admin_user) }

      it { is_expected.to be_allowed_to(:registrants?) }
    end

    context "with owner" do
      subject { policy_for(record: owned_event, user: regular_user) }

      it { is_expected.to be_allowed_to(:registrants?) }
    end

    context "with non-owner regular user" do
      subject { policy_for(record: published_event, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:registrants?) }
    end

    context "with no user" do
      subject { policy_for(record: published_event, user: nil) }

      it { is_expected.not_to be_allowed_to(:registrants?) }
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

  describe "#google_analytics?" do
    context "with admin user" do
      subject { policy_for(record: published_event, user: admin_user) }

      it { is_expected.to be_allowed_to(:google_analytics?) }
    end

    context "with regular user" do
      subject { policy_for(record: published_event, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:google_analytics?) }
    end

    context "with no user" do
      subject { policy_for(record: published_event, user: nil) }

      it { is_expected.not_to be_allowed_to(:google_analytics?) }
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

      it "returns only visible events with open registration or active registrations" do
        scope = policy.apply_scope(Event.all, type: :active_record_relation)
        sql = scope.to_sql
        expect(sql).to include('`events`.`published` = TRUE')
        expect(sql).to include("events.end_date >=")
        expect(sql).to include("events.registration_close_date IS NULL OR events.registration_close_date >=")
        expect(sql).to include("LEFT OUTER JOIN event_registrations")
        expect(sql).to include("event_registrations.status IN")
      end
    end

    context "with no user" do
      let(:policy) { policy_for(record: Event, user: nil) }

      it "excludes ended events and events with closed registration" do
        scope = policy.apply_scope(Event.all, type: :active_record_relation)
        sql = scope.to_sql
        expect(sql).to include('`events`.`published` = TRUE')
        expect(sql).to include("events.end_date >=")
        expect(sql).to include("events.registration_close_date IS NULL OR events.registration_close_date >=")
        expect(sql).not_to include("LEFT OUTER JOIN")
      end
    end
  end

  # The report suite's rows: what the viewer may aggregate over, regardless of the
  # filter params they send.
  describe "relation_scope(:reportable)" do
    let!(:owner) { create(:user) }
    let!(:owned) { create(:event, created_by: owner) }
    let!(:other) { create(:event) }

    def reportable_for(user)
      described_class.new(Event, user: user)
        .apply_scope(Event.all, type: :active_record_relation, name: :reportable)
    end

    it "returns every event for an admin" do
      expect(reportable_for(create(:user, :admin))).to contain_exactly(owned, other)
    end

    it "returns only their own events for an event owner" do
      expect(reportable_for(owner)).to contain_exactly(owned)
    end

    it "returns nothing for a user who owns no events" do
      expect(reportable_for(create(:user))).to be_empty
    end

    it "returns nothing for a guest" do
      expect(reportable_for(nil)).to be_empty
    end
  end

  describe "#cross_event_reports?" do
    let!(:owner) { create(:user) }

    before { create(:event, created_by: owner) }

    it "allows an admin" do
      expect(policy_for(record: Event, user: create(:user, :admin))).to be_allowed_to(:cross_event_reports?)
    end

    it "allows an event owner — the :reportable scope narrows their rows" do
      expect(policy_for(record: Event, user: owner)).to be_allowed_to(:cross_event_reports?)
    end

    it "denies a user who owns no events" do
      expect(policy_for(record: Event, user: create(:user))).not_to be_allowed_to(:cross_event_reports?)
    end

    it "denies a guest" do
      expect(policy_for(record: Event, user: nil)).not_to be_allowed_to(:cross_event_reports?)
    end
  end
end
