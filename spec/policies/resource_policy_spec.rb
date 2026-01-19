require "rails_helper"

RSpec.describe ResourcePolicy, type: :policy do
  let(:regular_user) { create(:user, super_user: false) }
  let(:super_user) { create(:user, super_user: true) }
  let(:resource_owner) { create(:user, super_user: false) }
  let(:published_resource) { create(:resource, user: resource_owner, inactive: false) }
  let(:unpublished_resource) { create(:resource, user: resource_owner, inactive: true) }
  let(:owned_resource) { create(:resource, user: regular_user, inactive: false) }

  describe_rule :index? do
    it "allows everyone to view index" do
      expect(described_class).to be_allowed_to(:index?, user: regular_user)
      expect(described_class).to be_allowed_to(:index?, user: super_user)
    end
  end

  describe_rule :show? do
    context "when user is a super user" do
      it "allows viewing any resource" do
        expect(described_class).to be_allowed_to(:show?, published_resource, user: super_user)
        expect(described_class).to be_allowed_to(:show?, unpublished_resource, user: super_user)
      end
    end

    context "when user is a regular user" do
      it "allows viewing published resources" do
        expect(described_class).to be_allowed_to(:show?, published_resource, user: regular_user)
      end

      it "denies viewing unpublished resources" do
        expect(described_class).not_to be_allowed_to(:show?, unpublished_resource, user: regular_user)
      end
    end
  end

  describe_rule :new? do
    it "allows super users to create resources" do
      expect(described_class).to be_allowed_to(:new?, user: super_user)
    end

    it "denies regular users from creating resources" do
      expect(described_class).not_to be_allowed_to(:new?, user: regular_user)
    end
  end

  describe_rule :create? do
    it "allows super users to create resources" do
      expect(described_class).to be_allowed_to(:create?, user: super_user)
    end

    it "denies regular users from creating resources" do
      expect(described_class).not_to be_allowed_to(:create?, user: regular_user)
    end
  end

  describe_rule :update? do
    context "when user is a super user" do
      it "allows updating any resource" do
        expect(described_class).to be_allowed_to(:update?, published_resource, user: super_user)
        expect(described_class).to be_allowed_to(:update?, unpublished_resource, user: super_user)
      end
    end

    context "when user is the resource owner" do
      it "allows updating their own resource" do
        expect(described_class).to be_allowed_to(:update?, owned_resource, user: regular_user)
      end
    end

    context "when user is not the owner" do
      it "denies updating someone else's resource" do
        expect(described_class).not_to be_allowed_to(:update?, published_resource, user: regular_user)
      end
    end
  end

  describe_rule :edit? do
    it "has the same permissions as update?" do
      expect(described_class).to be_allowed_to(:edit?, owned_resource, user: regular_user)
      expect(described_class).not_to be_allowed_to(:edit?, published_resource, user: regular_user)
      expect(described_class).to be_allowed_to(:edit?, published_resource, user: super_user)
    end
  end

  describe_rule :destroy? do
    it "has the same permissions as update?" do
      expect(described_class).to be_allowed_to(:destroy?, owned_resource, user: regular_user)
      expect(described_class).not_to be_allowed_to(:destroy?, published_resource, user: regular_user)
      expect(described_class).to be_allowed_to(:destroy?, published_resource, user: super_user)
    end
  end

  describe_rule :download? do
    it "allows everyone to download resources" do
      expect(described_class).to be_allowed_to(:download?, published_resource, user: regular_user)
      expect(described_class).to be_allowed_to(:download?, published_resource, user: super_user)
    end
  end

  describe_rule :filter_published? do
    it "allows super users to filter by published status" do
      expect(described_class).to be_allowed_to(:filter_published?, user: super_user)
    end

    it "denies regular users from filtering by published status" do
      expect(described_class).not_to be_allowed_to(:filter_published?, user: regular_user)
    end
  end

  describe_rule :search? do
    it "allows super users to search" do
      expect(described_class).to be_allowed_to(:search?, user: super_user)
    end

    it "denies regular users from searching" do
      expect(described_class).not_to be_allowed_to(:search?, user: regular_user)
    end
  end

  describe_rule :stories? do
    it "allows everyone to view stories" do
      expect(described_class).to be_allowed_to(:stories?, user: regular_user)
      expect(described_class).to be_allowed_to(:stories?, user: super_user)
    end
  end

  describe "relation_scope" do
    before do
      published_resource
      unpublished_resource
    end

    context "when user is a super user" do
      it "includes all resources" do
        scope = described_class.new(user: super_user).apply_scope(Resource.all, type: :active_record_relation)
        expect(scope).to include(published_resource)
        expect(scope).to include(unpublished_resource)
      end
    end

    context "when user is a regular user" do
      it "includes only published resources" do
        scope = described_class.new(user: regular_user).apply_scope(Resource.all, type: :active_record_relation)
        expect(scope).to include(published_resource)
        expect(scope).not_to include(unpublished_resource)
      end
    end
  end
end
