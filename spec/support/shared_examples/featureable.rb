# spec/support/shared_examples/featureable.rb
RSpec.shared_examples "featureable" do |factory:|
  let!(:featured_only) do
    create(factory,
      featured: true,
      inactive: false
    )
  end

  let!(:publicly_featured_only) do
    create(factory,
      publicly_featured: true,
      publicly_visible: true,
      inactive: false
    )
  end

  let!(:both_featured) do
    create(factory,
      featured: true,
      publicly_featured: true,
      publicly_visible: true,
      inactive: false
    )
  end

  let!(:inactive_featured) do
    create(factory,
      featured: true,
      inactive: true
    )
  end

  let!(:inactive_publicly_featured) do
    create(factory,
      publicly_featured: true,
      publicly_visible: true,
      inactive: true
    )
  end

  describe ".featured" do
    it "returns only active records with featured: true" do
      expect(described_class.featured)
        .to contain_exactly(featured_only, both_featured)
    end
  end

  describe ".publicly_featured" do
    it "returns only active records with publicly_featured: true and publicly_visible: true" do
      expect(described_class.publicly_featured)
        .to contain_exactly(publicly_featured_only, both_featured)
    end
  end
end
