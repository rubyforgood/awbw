require "rails_helper"

RSpec.describe "the comment icon on an affiliation row", type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let!(:affiliation) do
    create(:affiliation, person: person, organization: organization,
                         title: "Facilitator", start_date: 1.year.ago.to_date)
  end

  before { sign_in create(:user, :admin) }

  def comment_link(body)
    Nokogiri::HTML(body).at_css("a[href*='comments-section']")
  end

  it "is not rendered when the affiliation has no comments" do
    get edit_person_path(person)

    expect(comment_link(response.body)).to be_nil
  end

  it "links to the affiliation editor's comments section, in a new tab" do
    affiliation.comments.create!(body: "Ended after the training")

    get edit_person_path(person)

    link = comment_link(response.body)
    expect(link["href"]).to eq(
      edit_affiliation_path(affiliation, return_to: "person", origin_id: person.id, anchor: "comments-section")
    )
    expect(link["target"]).to eq("_blank")
    expect(link["rel"]).to eq("noopener")
  end

  it "sends you back to whichever editor you came from" do
    affiliation.comments.create!(body: "A note")

    get edit_organization_path(organization)

    expect(comment_link(response.body)["href"]).to eq(
      edit_affiliation_path(affiliation, return_to: "organization", origin_id: organization.id, anchor: "comments-section")
    )
  end

  # The gear in the same row is the other way into this editor; the two must agree
  # or the eyebrow sends you somewhere different depending on which you clicked.
  it "carries the same return_to and origin_id as the gear beside it" do
    affiliation.comments.create!(body: "A note")

    get edit_person_path(person)

    doc = Nokogiri::HTML(response.body)
    gear = doc.at_css("a[title^='Edit affiliation']")["href"]
    comment = doc.at_css("a[href*='comments-section']")["href"]
    expect(comment).to eq("#{gear}#comments-section")
  end

  it "lands on a section that actually exists on the affiliation editor" do
    affiliation.comments.create!(body: "A note")

    get edit_affiliation_path(affiliation)

    expect(Nokogiri::HTML(response.body).at_css("#comments-section")).to be_present
  end
end
