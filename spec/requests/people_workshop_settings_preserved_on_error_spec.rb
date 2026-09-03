require "rails_helper"

# Workshop-settings category checkboxes are applied through
# TagAssignable#assign_associations, which only runs on a successful save. When a
# validation error (e.g. a malformed email) re-renders the edit form, the just-
# submitted selections must still reflect what the admin checked — not silently
# revert to the last-saved database state like they used to.
RSpec.describe "People edit — workshop settings preserved on validation error", type: :request do
  let(:category_type) { create(:category_type, :published, profile_specific: true) }
  let(:category) { create(:category, :published, category_type: category_type) }
  let(:person) { create(:person) }

  before { sign_in create(:user, :admin) }

  def checkbox_for(category)
    Nokogiri::HTML(response.body).at_css("#person_category_ids_#{category.id}")
  end

  it "keeps a newly-checked workshop setting checked after an email validation error" do
    patch person_path(person), params: {
      person: {
        email: "not-an-email",
        category_ids: [ category.id ],
        managed_category_type_ids: [ category_type.id ]
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(checkbox_for(category)&.[]("checked")).to eq("checked")
  end

  it "keeps an unchecked workshop setting unchecked after an email validation error" do
    create(:categorizable_item, categorizable: person, category: category)

    patch person_path(person), params: {
      person: {
        email: "not-an-email",
        category_ids: [],
        managed_category_type_ids: [ category_type.id ]
      }
    }

    expect(response).to have_http_status(:unprocessable_content)
    expect(checkbox_for(category)&.[]("checked")).to be_nil
  end
end
