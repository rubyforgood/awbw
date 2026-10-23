require "rails_helper"

RSpec.describe "Person profile stories section", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner_user) { create(:user, :with_person) }
  let(:person) { owner_user.person }

  before { sign_in admin }

  # The section lazy-loads via a Turbo Frame, so request it the way the frame does.
  def get_stories_section
    get person_path(person, section: "stories"),
        headers: { "Turbo-Frame" => "person_stories_section" }
  end

  it "shows stories the person authored" do
    create(:story, :published, title: "Authored Story", author: person)

    get_stories_section

    expect(response).to be_successful
    expect(response.body).to include("Authored Story")
  end

  it "shows stories the person was spotlighted in" do
    create(:story, :published, title: "Spotlight Story", spotlighted_facilitator: person)

    get_stories_section

    expect(response.body).to include("Spotlight Story")
  end

  it "excludes stories the person only created but credited to someone else" do
    create(:story, :published, title: "Only Created Story",
                               created_by: owner_user, author: create(:person))

    get_stories_section

    expect(response.body).not_to include("Only Created Story")
  end

  it "flags an anonymously-credited authored story" do
    create(:story, :published, title: "Hush Story",
                               author: person, author_credit_preference: "anonymous")

    get_stories_section

    expect(response.body).to include("Hush Story")
    expect(response.body).to include("Credited as Anonymous")
  end

  it "never flags a spotlighted story, even when the person is anonymous" do
    person.update!(anonymous_contributions: true)
    create(:story, :published, title: "Spotlight Story", spotlighted_facilitator: person)

    get_stories_section

    expect(response.body).to include("Spotlight Story")
    expect(response.body).not_to include("Credited as Anonymous")
  end

  it "shows an admin a funder-only authored story, flagged with the chip" do
    create(:story, :published, :funder_only, title: "Funder Authored Story", author: person)

    get_stories_section

    expect(response.body).to include("Funder Authored Story")
    expect(response.body).to include("Funder-only")
  end

  context "as the profile owner" do
    before { sign_in owner_user }

    it "shows the owner their own funder-only authored story" do
      create(:story, :published, :funder_only, title: "My Funder Story", author: person)

      get_stories_section

      expect(response.body).to include("My Funder Story")
    end
  end

  context "as a different, non-admin viewer" do
    before { sign_in create(:user) }

    def make_viewable(profile_person)
      profile_person.update!(profile_is_searchable: true)
      create(:affiliation, person: profile_person)
    end

    def get_stories_section_for(profile_person)
      get person_path(profile_person, section: "stories"),
          headers: { "Turbo-Frame" => "person_stories_section" }
    end

    it "shows the spotlight badge even when the spotlight story itself is hidden from the viewer" do
      make_viewable(person)
      create(:story, title: "Draft Spotlight", spotlighted_facilitator: person, published: false)

      get person_path(person)
      expect(response).to be_successful
      expect(response.body).to include("Spotlighted Facilitator")

      get_stories_section
      expect(response.body).not_to include("Draft Spotlight")
    end

    context "with an anonymous credit" do
      let(:co_author) { create(:person) }

      before do
        make_viewable(person)
        make_viewable(co_author)
        create(:story, :published, title: "Anchor Story", author: person, co_author:)
      end

      it "hides a story from the profile of the author who chose anonymous" do
        create(:story, :published, title: "Hush Authored", author: person, author_credit_preference: "anonymous")

        get_stories_section

        expect(response.body).to include("Anchor Story")
        expect(response.body).not_to include("Hush Authored")
      end

      it "hides a story from only the co-author's profile when the co-author chose anonymous" do
        create(:story, :published, title: "Hush Coauthored", author: person, co_author:,
                                   co_author_credit_preference: "anonymous")

        get_stories_section_for(co_author)
        expect(response.body).to include("Anchor Story")
        expect(response.body).not_to include("Hush Coauthored")

        get_stories_section
        expect(response.body).to include("Hush Coauthored")
      end

      it "hides a story from both profiles when both authors chose anonymous" do
        create(:story, :published, title: "Hush Both", author: person, co_author:,
                                   author_credit_preference: "anonymous", co_author_credit_preference: "anonymous")

        get_stories_section
        expect(response.body).to include("Anchor Story")
        expect(response.body).not_to include("Hush Both")

        get_stories_section_for(co_author)
        expect(response.body).to include("Anchor Story")
        expect(response.body).not_to include("Hush Both")
      end

      it "keeps a spotlight on the profile of a person who contributes anonymously" do
        create(:story, :published, title: "Spotlight Story", spotlighted_facilitator: co_author)
        co_author.update!(anonymous_contributions: true)

        get_stories_section_for(co_author)

        expect(response.body).to include("Spotlight Story")
        expect(response.body).not_to include("Anchor Story")
      end
    end

    it "lists only the published stories the viewer may open, for every role the person plays" do
      person.update!(profile_is_searchable: true)
      create(:affiliation, person:)
      create(:story, :published, title: "Published Authored", author: person)
      create(:story, :published, title: "Published Coauthored", author: create(:person), co_author: person)
      create(:story, :published, title: "Published Spotlight", spotlighted_facilitator: person)
      create(:story, title: "Draft Authored", author: person, published: false)
      create(:story, title: "Draft Coauthored", author: create(:person), co_author: person, published: false)
      create(:story, title: "Draft Spotlight", spotlighted_facilitator: person, published: false)

      get_stories_section

      expect(response).to be_successful
      expect(response.body).to include("Published Authored", "Published Coauthored", "Published Spotlight")
      expect(response.body).not_to include("Draft Authored")
      expect(response.body).not_to include("Draft Coauthored")
      expect(response.body).not_to include("Draft Spotlight")
    end

    it "hides the person's funder-only authored story" do
      create(:story, :published, :publicly_visible, :funder_only,
             title: "Hidden Funder Story", author: person)

      get_stories_section

      expect(response.body).not_to include("Hidden Funder Story")
    end
  end
end
