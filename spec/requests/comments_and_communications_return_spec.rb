require "rails_helper"

RSpec.describe "Returning to comments & communications from a person chip", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:person) { create(:person) }

  before { sign_in admin }

  it "gives the person edit page an eyebrow back to that person's feed" do
    get edit_person_path(person, return_to: "comments_and_communications", feed_person_id: person.id)

    back = Nokogiri::HTML(response.body).css("a").find { |a| a.text.strip == "Comments & communications" }
    expect(back["href"]).to eq(comments_and_communications_path(person_id: person.id))
  end

  it "gives the person edit page an eyebrow back to the everyone feed" do
    get edit_person_path(person, return_to: "comments_and_communications")

    back = Nokogiri::HTML(response.body).css("a").find { |a| a.text.strip == "Comments & communications" }
    expect(back["href"]).to eq(comments_and_communications_path)
  end

  it "carries the origin through the form and returns to the feed after saving" do
    get edit_person_path(person, return_to: "comments_and_communications", feed_person_id: person.id)

    form = Nokogiri::HTML(response.body).at_css("form[action='#{person_path(person)}']")
    expect(form.at_css("input[name='return_to'][value='comments_and_communications']")).to be_present
    expect(form.at_css("input[name='feed_person_id'][value='#{person.id}']")).to be_present

    patch person_path(person), params: { person: { first_name: "Updated" }, return_to: "comments_and_communications", feed_person_id: person.id }

    expect(response).to redirect_to(comments_and_communications_path(person_id: person.id))
  end
end
