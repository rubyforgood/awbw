require "rails_helper"

RSpec.describe Publishable, type: :model do
  # State fixtures
  let!(:public_record) do
    Faq.create!(question: "Public", answer: "A", published: true, publicly_visible: true)
  end

  let!(:public_draft_record) do
    Faq.create!(question: "Public Draft", answer: "A", published: false, publicly_visible: true)
  end

  let!(:internal_draft_record) do
    Faq.create!(question: "Internal Draft", answer: "A", published: false, publicly_visible: false)
  end

  let!(:internal_record) do
    Faq.create!(question: "Internal", answer: "A", published: true, publicly_visible: false)
  end

  # ------------------------------------------------------------------

  describe ".published" do
    it "returns live records (public + internal) when no param" do
      expect(Faq.published)
        .to contain_exactly(public_record, internal_record)
    end

    it "returns live records (public + internal) when param is empty string" do
      expect(Faq.published(""))
        .to contain_exactly(public_record, internal_record)
    end

    it "returns live records (public + internal) when param is blank" do
      expect(Faq.published(nil))
        .to contain_exactly(public_record, internal_record)
    end

    it "returns live records (public + internal) when param is true" do
      expect(Faq.published(true))
        .to contain_exactly(public_record, internal_record)
    end

    it "returns live records (public + internal) when param is 'true'" do
      expect(Faq.published('true'))
        .to contain_exactly(public_record, internal_record)
    end

    it "returns drafts when flag is false" do
      expect(Faq.published(false))
        .to contain_exactly(public_draft_record, internal_draft_record)
    end

    it "returns drafts when flag is 'false'" do
      expect(Faq.published("false"))
        .to contain_exactly(public_draft_record, internal_draft_record)
    end
  end

  # ------------------------------------------------------------------

  describe ".publicly_visible" do
    it "returns only records visible to the public AND live" do
      expect(Faq.publicly_visible)
        .to contain_exactly(public_record)
    end

    it "excludes public drafts" do
      expect(Faq.publicly_visible)
        .not_to include(public_draft_record)
    end

    it "excludes internal live records" do
      expect(Faq.publicly_visible)
        .not_to include(internal_record)
    end

    it "excludes internal drafts" do
      expect(Faq.publicly_visible)
        .not_to include(internal_draft_record)
    end
  end
end
