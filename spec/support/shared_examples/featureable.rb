# spec/support/shared_examples/featureable.rb
RSpec.shared_examples "featureable" do |factory:|
  let!(:featured) do
    create(factory,
      featured: true,
      published: true
    )
  end

  let!(:publicly_featured) do
    create(factory,
      publicly_featured: true,
      publicly_visible: true,
      published: true
    )
  end

  let!(:both_featured) do
    create(factory,
      featured: true,
      publicly_featured: true,
      publicly_visible: true,
      published: true
    )
  end

  let!(:inactive_featured) do
    create(factory,
      featured: true,
      published: false
    )
  end

  let!(:inactive_publicly_featured) do
    create(factory,
      publicly_featured: true,
      publicly_visible: true,
      published: false
    )
  end

  describe ".featured" do
    let!(:normal_record) { create(factory, :published) }

    it "returns only active records with featured: true" do
      expect(described_class.featured)
        .to contain_exactly(featured, both_featured)
    end

    it "does not include publicly_featured-only records" do
      expect(described_class.featured).not_to include(publicly_featured)
    end

    it "does not include non-featured records" do
      expect(described_class.featured).not_to include(normal_record)
    end

    it "never returns unpublished records" do
      expect(described_class.featured).not_to include(inactive_featured)
    end

    it "returns a relation" do
      expect(described_class.featured).to be_a(ActiveRecord::Relation)
    end
  end

  describe ".publicly_featured" do
    it "returns only active records with publicly_featured: true and publicly_visible: true" do
      expect(described_class.publicly_featured)
        .to contain_exactly(publicly_featured, both_featured)
    end
  end

  describe ".featured_or_publicly_featured" do
    let!(:normal_record) { create(factory, :published) }

    it "returns records that are featured" do
      expect(described_class.featured_or_publicly_featured)
        .to include(featured, both_featured)
    end

    it "returns records that are publicly_featured and publicly_visible" do
      expect(described_class.featured_or_publicly_featured)
        .to include(publicly_featured, both_featured)
    end

    it "does not include records that are neither featured nor publicly_featured" do
      expect(described_class.featured_or_publicly_featured)
        .not_to include(normal_record)
    end

    it "does not include unpublished records" do
      expect(described_class.featured_or_publicly_featured)
        .not_to include(inactive_featured, inactive_publicly_featured)
    end

    it "does not return duplicates" do
      ids = described_class.featured_or_publicly_featured.pluck(:id)
      expect(ids).to eq(ids.uniq)
    end

    it "returns a relation" do
      expect(described_class.featured_or_publicly_featured)
        .to be_a(ActiveRecord::Relation)
    end
  end

end
