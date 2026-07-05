require "rails_helper"

# The person edit "Associated records" cards link each authored-content index
# (stories, workshops, workshop variations, community news, resources) filtered
# to that person via author_id. These cover the filter + the "Filtered to" banner.
RSpec.describe "Authored-content indexes filtered by author", type: :request do
  let(:admin)  { create(:user, :admin) }
  let(:author) { create(:person, first_name: "Ada", last_name: "Author") }
  let(:other)  { create(:person) }

  before { sign_in admin }

  it "scopes stories to the author and names them in the banner" do
    create(:story, :published, title: "Ada Story", author: author)
    create(:story, :published, title: "Other Story", author: other)

    get stories_path(author_id: author.id)
    expect(response.body).to include("Filtered to")
    expect(response.body).to include("Ada Author")

    get stories_path(author_id: author.id), headers: { "Turbo-Frame" => "stories_results" }
    expect(response.body).to include("Ada Story")
    expect(response.body).not_to include("Other Story")
  end

  it "scopes workshops to the author" do
    create(:workshop, published: true, title: "Ada Workshop", author: author)
    create(:workshop, published: true, title: "Other Workshop", author: other)

    get workshops_path(author_id: author.id)
    expect(response.body).to include("Filtered to")

    get workshops_path(author_id: author.id), headers: { "Turbo-Frame" => "workshops_results" }
    expect(response.body).to include("Ada Workshop")
    expect(response.body).not_to include("Other Workshop")
  end

  it "scopes workshop variations to the author" do
    published_workshop = create(:workshop, published: true)
    create(:workshop_variation, name: "Ada Variation", workshop: published_workshop, author: author)
    create(:workshop_variation, name: "Other Variation", workshop: published_workshop, author: other)

    get workshop_variations_path(author_id: author.id)

    expect(response.body).to include("Filtered to")
    expect(response.body).to include("Ada Variation")
    expect(response.body).not_to include("Other Variation")
  end

  it "scopes community news to the author" do
    create(:community_news, published: true, title: "Ada News", author: author)
    create(:community_news, published: true, title: "Other News", author: other)

    get community_news_index_path(author_id: author.id)
    expect(response.body).to include("Filtered to")

    get community_news_index_path(author_id: author.id), headers: { "Turbo-Frame" => "community_news_results" }
    expect(response.body).to include("Ada News")
    expect(response.body).not_to include("Other News")
  end

  it "scopes resources to the author" do
    create(:resource, title: "Ada Resource", author: author)
    create(:resource, title: "Other Resource", author: other)

    get resources_path(author_id: author.id)
    expect(response.body).to include("Filtered to")

    get resources_path(author_id: author.id), headers: { "Turbo-Frame" => "resources_results" }
    expect(response.body).to include("Ada Resource")
    expect(response.body).not_to include("Other Resource")
  end
end
