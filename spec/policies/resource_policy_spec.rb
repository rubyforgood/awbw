require "rails_helper"

RSpec.describe ResourcePolicy, type: :policy do
  let(:admin_user)        { build_stubbed(:user, super_user: true) }
  let(:regular_user)      { build_stubbed(:user, super_user: false) }
  let(:guest_user)        { nil }

  let(:public_resource) do
    build_stubbed(
      :resource,
      published: false,
      publicly_visible: true
    )
  end

  let(:published_resource) do
    build_stubbed(
      :resource,
      published: true,
      publicly_visible: false
    )
  end

  let(:private_resource) do
    build_stubbed(
      :resource,
      published: false,
      publicly_visible: false
    )
  end

  def policy_for(record:, user:)
    described_class.new(record, user: user)
  end

  # -----------------------------------------
  # index?
  # -----------------------------------------

  describe "#index?" do
    it "allows admin" do
      expect(policy_for(record: Resource, user: admin_user))
        .to be_allowed_to(:index?)
    end

    it "allows regular user" do
      expect(policy_for(record: Resource, user: regular_user))
        .to be_allowed_to(:index?)
    end

    it "allows guest" do
      expect(policy_for(record: Resource, user: guest_user))
        .to be_allowed_to(:index?)
    end
  end

  # -----------------------------------------
  # show?
  # -----------------------------------------

  describe "#show?" do
    context "admin" do
      it "can see anything" do
        expect(policy_for(record: private_resource, user: admin_user))
          .to be_allowed_to(:show?)
      end
    end

    context "regular user" do
      it "can see published resource" do
        expect(policy_for(record: published_resource, user: regular_user))
          .to be_allowed_to(:show?)
      end

      it "cannot see private resource" do
        expect(policy_for(record: private_resource, user: regular_user))
          .not_to be_allowed_to(:show?)
      end

      it "can see publicly visible resource" do
        expect(policy_for(record: public_resource, user: regular_user))
          .to be_allowed_to(:show?)
      end
    end

    context "guest" do
      it "can see publicly visible resource" do
        expect(policy_for(record: public_resource, user: guest_user))
          .to be_allowed_to(:show?)
      end

      it "cannot see published-only resource" do
        expect(policy_for(record: published_resource, user: guest_user))
          .not_to be_allowed_to(:show?)
      end
    end
  end

  # -----------------------------------------
  # create? / update?
  # -----------------------------------------

  describe "admin-only write actions" do
    [ :create?, :update?, :filter_published? ].each do |action|
      it "#{action} allows admin" do
        expect(policy_for(record: private_resource, user: admin_user))
          .to be_allowed_to(action)
      end

      it "#{action} denies regular user" do
        expect(policy_for(record: private_resource, user: regular_user))
          .not_to be_allowed_to(action)
      end

      it "#{action} denies guest" do
        expect(policy_for(record: private_resource, user: guest_user))
          .not_to be_allowed_to(action)
      end
    end
  end

  # -----------------------------------------
  # download?
  # -----------------------------------------

  describe "#download?" do
    it "allows admin" do
      expect(policy_for(record: private_resource, user: admin_user))
        .to be_allowed_to(:download?)
    end

    it "allows regular user" do
      expect(policy_for(record: private_resource, user: regular_user))
        .to be_allowed_to(:download?)
    end

    it "allows guest" do
      expect(policy_for(record: private_resource, user: guest_user))
        .to be_allowed_to(:download?)
    end
  end

  # -----------------------------------------
  # relation_scope
  # -----------------------------------------

  describe "relation_scope" do
    let!(:public_record)    { create(:resource, :publicly_visible, :published) }
    let!(:published_record) { create(:resource, :published) }
    let!(:internal_record)   { create(:resource) }

    context "admin" do
      it "returns all records" do
        policy = described_class.new(Resource, user: admin_user)
        scope  = policy.apply_scope(Resource.all, type: :active_record_relation)

        expect(scope).to contain_exactly(public_record, published_record, internal_record)
      end
    end

    context "regular user" do
      it "returns published records only" do
        policy = described_class.new(Resource, user: regular_user)
        scope  = policy.apply_scope(Resource.all, type: :active_record_relation)

        expect(scope).to contain_exactly(public_record, published_record)
      end
    end

    context "guest" do
      it "returns publicly visible records only" do
        policy = described_class.new(Resource, user: guest_user)
        scope  = policy.apply_scope(Resource.all, type: :active_record_relation)

        expect(scope).to contain_exactly(public_record)
      end
    end
  end
end
