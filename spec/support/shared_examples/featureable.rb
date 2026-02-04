# spec/support/shared_examples/featureable.rb
RSpec.shared_examples "featureable" do |factory:|
  let!(:featured_only) do
    create(factory,
      featured: true,
      inactive: false
    )
  end

  let!(:public_featured_only) do
    create(factory,
      public_featured: true,
      publicly_visible: true,
      inactive: false
    )
  end

  let!(:both_featured) do
    create(factory,
      featured: true,
      public_featured: true,
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

  let!(:inactive_public_featured) do
    create(factory,
      public_featured: true,
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

  describe ".public_featured" do
    it "returns only active records with public_featured: true and publicly_visible: true" do
      expect(described_class.public_featured)
        .to contain_exactly(public_featured_only, both_featured)
    end
  end
end
