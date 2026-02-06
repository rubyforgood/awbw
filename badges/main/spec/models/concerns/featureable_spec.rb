require "rails_helper"

RSpec.describe Featureable, type: :model do
  # Use a real model that includes the concern
  # Resource is perfect here

  let!(:featured_record) do
    create(:resource, :published, featured: true)
  end

  let!(:publicly_featured_record) do
    create(:resource, :published, publicly_featured: true, publicly_visible: true)
  end

  let!(:both_featured_record) do
    create(:resource, :published, featured: true, publicly_featured: true, publicly_visible: true)
  end

  let!(:internal_record) do
    create(:resource, :published)
  end

  let!(:unpublished_featured) do
    create(:resource, featured: true)
  end

  let!(:unpublished_publicly_featured) do
    create(:resource, publicly_featured: true, publicly_visible: true)
  end

  # ----------------------------------------------------

  describe ".featured" do
    it "returns only published records with featured: true" do
      expect(Resource.featured)
        .to contain_exactly(featured_record, both_featured_record)
    end

    it "does not include publicly_featured-only records" do
      expect(Resource.featured).not_to include(publicly_featured_record)
    end

    it "does not include non-featured records" do
      expect(Resource.featured).not_to include(internal_record)
    end

    it "does not include unpublished records" do
      expect(Resource.featured).not_to include(unpublished_featured)
    end

    it "includes featured records even if not publicly_visible" do
      hidden_featured = create(:resource, featured: true, publicly_visible: false, published: true)
      expect(Resource.featured).to include(hidden_featured)
    end

    it "is chainable" do
      expect(Resource.featured.where(id: featured_record.id))
        .to contain_exactly(featured_record)
    end
  end

  # ----------------------------------------------------

  describe ".publicly_featured" do
    it "returns only published, publicly_visible, publicly_featured records" do
      expect(Resource.publicly_featured)
        .to contain_exactly(publicly_featured_record, both_featured_record)
    end

    it "does not include featured-only records" do
      expect(Resource.publicly_featured).not_to include(featured_record)
    end

    it "does not include unpublished records" do
      expect(Resource.publicly_featured)
        .not_to include(unpublished_publicly_featured)
    end

    it "does not include publicly_featured records that are not publicly_visible" do
      hidden_publicly_featured = create(:resource,
                                        publicly_featured: true,
                                        publicly_visible: false,
                                        published: true
      )
      expect(Resource.publicly_featured).not_to include(hidden_publicly_featured)
    end

    it "is chainable" do
      expect(Resource.publicly_featured.where(id: publicly_featured_record.id))
        .to contain_exactly(publicly_featured_record)
    end

    it "does not raise if publicly_visible column exists" do
      expect { Resource.publicly_featured.to_a }.not_to raise_error
    end
  end

  # ----------------------------------------------------

  describe ".featured_or_publicly_featured" do
    it "returns union of featured and publicly_featured" do
      expect(Resource.featured_or_publicly_featured)
        .to contain_exactly(featured_record, publicly_featured_record, both_featured_record)
    end

    it "does not include normal records" do
      expect(Resource.featured_or_publicly_featured).not_to include(internal_record)
    end

    it "does not include unpublished records" do
      expect(Resource.featured_or_publicly_featured)
        .not_to include(unpublished_featured, unpublished_publicly_featured)
    end

    it "does not return duplicates" do
      ids = Resource.featured_or_publicly_featured.pluck(:id)
      expect(ids).to eq(ids.uniq)
    end
  end
end
