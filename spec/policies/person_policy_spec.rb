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

  def in_production
    allow(Rails.env).to receive(:production?).and_return(true)
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

      it { is_expected.to be_allowed_to(:index?) }

      it "is denied in production" do
        in_production
        is_expected.not_to be_allowed_to(:index?)
      end
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

    context "with regular user and a published person" do
      subject { policy_for(record: searchable_person, user: regular_user) }

      before { allow(searchable_person).to receive(:published?).and_return(true) }

      it { is_expected.to be_allowed_to(:show?) }

      it "is denied in production" do
        in_production
        is_expected.not_to be_allowed_to(:show?)
      end
    end

    context "with regular user and an unpublished person" do
      subject { policy_for(record: non_searchable_person, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end

    context "with no user" do
      subject { policy_for(record: searchable_person, user: nil) }

      before { allow(searchable_person).to receive(:published?).and_return(true) }

      it { is_expected.not_to be_allowed_to(:show?) }
    end
  end

  describe "#own_record?" do
    context "with admin user looking at someone else" do
      subject { policy_for(record: non_searchable_person, user: admin_user) }

      it { is_expected.to be_allowed_to(:own_record?) }
    end

    context "with owner" do
      subject { policy_for(record: owned_person, user: owner_user) }

      it { is_expected.to be_allowed_to(:own_record?) }
    end

    context "with a regular user who is not the owner (even a searchable person)" do
      subject { policy_for(record: searchable_person, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:own_record?) }
    end

    context "with no user" do
      subject { policy_for(record: searchable_person, user: nil) }

      it { is_expected.not_to be_allowed_to(:own_record?) }
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

      it { is_expected.to be_allowed_to(:edit?) }
      it { is_expected.to be_allowed_to(:update?) }

      it "is denied in production" do
        in_production
        is_expected.not_to be_allowed_to(:edit?)
        is_expected.not_to be_allowed_to(:update?)
      end
    end

    context "with regular user who is not the owner" do
      subject { policy_for(record: searchable_person, user: regular_user) }

      it { is_expected.not_to be_allowed_to(:edit?) }
      it { is_expected.not_to be_allowed_to(:update?) }
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

  describe "params_filter(:index)" do
    let(:filters) do
      ActionController::Parameters.new(
        contact_info: "ada", role: "story_authors", staff_tag_ids: [ "1" ],
        topic_subscription_type_id: [ "2" ], facilitator_status: "active",
        membership_status: "paid"
      )
    end

    def index_filters_for(user)
      policy_for(record: Person, user: user)
        .apply_scope(filters, type: :action_controller_params, name: :index)
    end

    it "keeps every filter for an admin" do
      expect(index_filters_for(admin_user).keys).to match_array(filters.keys)
    end

    it "drops the admin-only filters for a regular user" do
      expect(index_filters_for(regular_user).keys).to contain_exactly("shared_contact_info")
    end

    it "drops the admin-only filters for a visitor" do
      expect(index_filters_for(nil).keys).to contain_exactly("shared_contact_info")
    end

    it "narrows a non-admin's contact-info search to shared contact info" do
      expect(index_filters_for(regular_user)[:shared_contact_info]).to eq("ada")
    end
  end

  describe "default params_filter" do
    let(:submitted_attributes) do
      ActionController::Parameters.new(
        first_name: "Ada",
        email: "changed@example.com",
        email_type: "work",
        email_2: "second@example.com",
        email_2_type: "personal",
        notes: "Internal note",
        racial_ethnic_identity: "Self-described",
        sectorable_items_attributes: { "0" => { sector_id: "3", is_primary: "1", is_leader: "1" } },
        user_attributes: {
          id: "1", person_id: "2", email: "changed@example.com", super_user: "1", inactive: "1",
          notes: "Internal note", phone: "555-0100", time_zone: "Hawaii"
        },
        affiliations_attributes: { "0" => { id: "1", title: "Changed title" } },
        professional_licenses_attributes: { "0" => { kind: "LCSW", number: "123" } }
      )
    end

    def write_params_for(user)
      policy_for(record: owned_person, user: user)
        .apply_scope(submitted_attributes, type: :action_controller_params)
    end

    it "strips admin-only fields while retaining owner-editable profile fields" do
      filtered = write_params_for(owner_user)

      expect(filtered.keys).to contain_exactly(
        "first_name", "email_type", "email_2_type", "sectorable_items_attributes",
        "user_attributes", "professional_licenses_attributes"
      )
    end

    it "strips admin-only user attributes while retaining the rest" do
      expect(write_params_for(owner_user)[:user_attributes].to_h)
        .to eq("id" => "1", "phone" => "555-0100", "time_zone" => "Hawaii")
    end

    it "strips the sector leader flag while retaining the sector and its primary flag" do
      expect(write_params_for(owner_user)[:sectorable_items_attributes].to_h)
        .to eq("0" => { "sector_id" => "3", "is_primary" => "1" })
    end

    it "retains the permitted fields for an admin" do
      expect(write_params_for(admin_user).keys).to match_array(submitted_attributes.keys)
    end
  end
end
