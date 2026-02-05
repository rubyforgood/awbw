# spec/support/shared_examples/featureable.rb
RSpec.shared_examples "featureable" do |factory:|
  let!(:featured_only) do
    create(factory,
      featured: true,
      published: true
    )
  end

  let!(:publicly_featured_only) do
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
