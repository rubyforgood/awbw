require "rails_helper"

RSpec.describe "/quotes", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in admin }

  describe "GET /new" do
    it "renders the visibility card with the published flag" do
      get new_quote_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("admin-only bg-blue-100")
      expect(response.body).to include('name="quote[published]"')
      expect(response.body).to include(VisibilityFlagsHelper::FLAG_DEFINITIONS[:published][:description])
    end

    it "renders sector and category toggles" do
      sector = create(:sector, :published, name: "Domestic violence")
      category = create(:category, :published, name: "Watercolor",
                        category_type: create(:category_type, :published))

      get new_quote_path

      expect(response.body).to include('name="quote[sector_ids][]"')
      expect(response.body).to include('name="quote[category_ids][]"')
      expect(response.body).to include(sector.name)
      expect(response.body).to include(category.name)
    end
  end

  describe "tagging" do
    let(:sector) { create(:sector) }
    let(:category) { create(:category) }

    it "creates a quote with the selected sectors and categories" do
      post quotes_path, params: {
        quote: { body: "Tagged quote", sector_ids: [ sector.id ], category_ids: [ category.id ] }
      }

      quote = Quote.last
      expect(quote.sectors).to include(sector)
      expect(quote.categories).to include(category)
    end

    it "updates a quote's sectors and categories" do
      quote = create(:quote, sectors: [ sector ])
      other_sector = create(:sector)

      patch quote_path(quote), params: {
        quote: { sector_ids: [ other_sector.id ], category_ids: [ category.id ] }
      }

      expect(quote.reload.sectors).to contain_exactly(other_sector)
      expect(quote.categories).to contain_exactly(category)
    end
  end
end
