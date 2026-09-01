require "rails_helper"

RSpec.describe "Organization age ranges", type: :request do
  let(:admin) { create(:user, :admin) }
  let!(:organization_status) { create(:organization_status, name: "Active") }
  let(:organization) { create(:organization, organization_status: organization_status) }

  # AgeGroupTaggable matches the type by the exact name "AgeRange".
  let(:age_type) { create(:category_type, :published, name: "AgeRange") }
  # Created in order so the positioned gem assigns positions children < teens < adults.
  let!(:children) { create(:category, :published, category_type: age_type, name: "Children (0-12)") }
  let!(:teens) { create(:category, :published, category_type: age_type, name: "Teens (13-17)") }
  let!(:adults) { create(:category, :published, category_type: age_type, name: "Adults (18+)") }

  # A profile-specific category the form edits via category_ids (workshop settings).
  let(:workshop_type) { create(:category_type, :published, name: "WorkshopEnvironment", profile_specific: true) }
  let!(:in_person) { create(:category, :published, category_type: workshop_type, name: "In person") }

  before { sign_in admin }

  # Age ranges save as age_range_categorizable_items nested attributes (the cocoon
  # chip picker), not category_ids — mirroring the person form.
  def update_org(age_items:, category_ids: [ "" ], managed_type_ids: [ workshop_type.id ])
    patch organization_path(organization), params: {
      organization: {
        name: organization.name,
        organization_status_id: organization_status.id,
        category_ids: category_ids,
        managed_category_type_ids: managed_type_ids,
        age_range_categorizable_items_attributes: age_items
      }
    }
  end

  describe "edit form" do
    it "renders the cocoon age-range chip picker, not the windows dropdown" do
      get edit_organization_path(organization)

      expect(response.body).to include("primary-tag")
      expect(response.body).to include("Add age range")
      expect(response.body).to include("Children (0-12)")
      expect(response.body).not_to include("organization[windows_type_id]")
    end
  end

  describe "saving age ranges" do
    it "tags the selected age ranges and marks the chosen one primary" do
      update_org(age_items: [
        { category_id: children.id, is_primary: "1" },
        { category_id: adults.id, is_primary: "0" }
      ])

      organization.reload
      expect(organization.primary_age_groups).to contain_exactly(children)
      expect(organization.additional_age_groups).to contain_exactly(adults)
    end

    it "removes an age range via _destroy" do
      organization.categories << children
      item = organization.categorizable_items.find_by(category: children)

      update_org(age_items: [ { id: item.id, category_id: children.id, _destroy: "1" } ])

      organization.reload
      expect(organization.primary_age_groups).to be_empty
      expect(organization.additional_age_groups).to be_empty
    end

    it "dedupes duplicate selections instead of raising RecordNotUnique" do
      expect {
        update_org(age_items: [
          { category_id: children.id, is_primary: "0" },
          { category_id: children.id, is_primary: "1" }
        ])
      }.not_to raise_error

      organization.reload
      expect(organization.categorizable_items.where(category: children).count).to eq(1)
      expect(organization.primary_age_groups).to contain_exactly(children)
    end
  end

  describe "preserving non-AgeRange category connections" do
    it "keeps the organization's workshop-setting taggings when saving age ranges" do
      organization.categories << in_person

      update_org(age_items: [ { category_id: children.id, is_primary: "1" } ],
                 category_ids: [ "", in_person.id.to_s ])

      organization.reload
      expect(organization.categories).to include(in_person)
      expect(organization.primary_age_groups).to contain_exactly(children)
    end

    # An admin can flag the AgeRange type profile_specific in /category_types. The
    # form renders no age checkboxes either way, so the type has to stay out of
    # managed_category_type_ids — otherwise assign_associations sees an empty
    # selection for a managed type and deletes what the chip picker just saved.
    it "keeps the age ranges when an admin has marked the AgeRange type profile_specific" do
      age_type.update!(profile_specific: true)
      organization.age_range_categorizable_items.create!(category: children, is_primary: false)

      get edit_organization_path(organization)
      managed_type_ids = Nokogiri::HTML(response.body)
        .css("input[name='organization[managed_category_type_ids][]']")
        .filter_map { |input| input["value"].presence }
      expect(managed_type_ids).not_to include(age_type.id.to_s)

      update_org(age_items: [
        { id: organization.age_range_categorizable_items.first.id, category_id: children.id, is_primary: "0" },
        { category_id: teens.id, is_primary: "1" }
      ], managed_type_ids: managed_type_ids)

      organization.reload
      expect(organization.primary_age_groups).to contain_exactly(teens)
      expect(organization.additional_age_groups).to contain_exactly(children)
    end
  end

  # The form posts every existing chip back as a nested row alongside category_ids.
  # If category_ids were mass-assigned it would replace the whole categories
  # collection mid-assign, deleting those rows before their nested attributes are
  # applied — the resubmitted ids then point at nothing and the save 404s.
  describe "re-saving the form with existing age ranges" do
    it "round-trips the already-tagged age ranges" do
      organization.age_range_categorizable_items.create!(category: children, is_primary: true)
      item = organization.age_range_categorizable_items.first
      organization.categories << in_person

      patch organization_path(organization), params: {
        organization: {
          name: organization.name,
          organization_status_id: organization_status.id,
          age_range_categorizable_items_attributes: { "0" => { id: item.id, category_id: children.id, is_primary: "1" } },
          category_ids: [ "", in_person.id.to_s ],
          managed_category_type_ids: [ "", workshop_type.id.to_s ]
        }
      }

      expect(response).to have_http_status(:see_other)
      organization.reload
      expect(organization.primary_age_groups).to contain_exactly(children)
      expect(organization.categories).to include(in_person)
    end
  end
end
