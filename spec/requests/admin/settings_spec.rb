require "rails_helper"

RSpec.describe "Admin::Settings", type: :request do
  let(:admin) { create(:user, :admin) }

  describe "GET edit" do
    it "renders for an admin before any row exists" do
      sign_in admin

      get admin_settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("App settings")
    end

    it "counts the featured stories each audience can see on the portal home" do
      create_list(:story, 2, :published, :featured)
      create(:story, :published, :publicly_visible, :publicly_featured)
      sign_in admin

      get admin_settings_path

      expect(response.body).to include("2 stories featured for them")
      expect(response.body).to include("1 story publicly featured")
    end

    it "names what the chosen organization supplies" do
      organization = create(:organization, name: "Portal Runner", tax_id: "12-3456789")
      Setting.create!(organization: organization)
      sign_in admin

      get admin_settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Portal Runner")
      expect(response.body).to include("12-3456789")
    end

    it "offers the app organization's addresses to choose from" do
      organization = create(:organization, name: "Portal Runner")
      create(:address, addressable: organization, street_address: "100 Main St",
                       city: "Anytown", state: "CA", zip_code: "90001")
      Setting.create!(organization: organization)
      sign_in admin

      get admin_settings_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Return address")
      expect(response.body).to include("100 Main St")
    end

    it "prompts for an address it has none for, and preselects the one it has" do
      organization = create(:organization)
      chosen = create(:address, addressable: organization, street_address: "100 Main St")
      create(:address, addressable: organization, street_address: "200 Other Rd")
      Setting.create!(organization: organization, return_address: chosen)
      sign_in admin

      get admin_settings_path

      doc = Nokogiri::HTML(response.body)
      return_options = doc.at_css("select[name='setting[return_address_id]']").css("option")
      remittance_options = doc.at_css("select[name='setting[remittance_address_id]']").css("option")
      expect(return_options.map(&:text).grep(/Choose an address/)).to be_empty
      expect(return_options.find { |option| option["selected"] }.text).to include("100 Main St")
      expect(remittance_options.first.text).to eq("Choose an address")
      expect(remittance_options.none? { |option| option["selected"] }).to be(true)
    end

    it "offers the named CE administrator as the picker's current choice" do
      administrator = create(:person, first_name: "Robin", last_name: "Signer")
      Setting.create!(ce_administrator: administrator)
      sign_in admin

      get admin_settings_path

      options = Nokogiri::HTML(response.body).at_css("select[name='setting[ce_administrator_id]']").css("option")
      expect(options.find { |option| option["selected"] }.text).to include("Robin Signer")
    end

    it "offers the chosen import user as the picker's current choice" do
      Setting.create!(import_user: create(:user, email: "imports@example.com"))
      sign_in admin

      get admin_settings_path

      options = Nokogiri::HTML(response.body).at_css("select[name='setting[import_user_id]']").css("option")
      expect(options.find { |option| option["selected"] }.text).to include("imports@example.com")
    end

    it "is denied to a non-admin" do
      sign_in create(:user)

      get admin_settings_path

      expect(response).not_to have_http_status(:ok)
    end
  end

  describe "PATCH update" do
    before { sign_in admin }

    it "saves how many featured stories the portal home shows" do
      patch admin_settings_path, params: { setting: { home_featured_stories_limit: "4" } }

      expect(response).to have_http_status(:see_other)
      expect(Setting.home_featured_stories_limit).to eq(4)
    end

    it "creates the row on first save" do
      organization = create(:organization)

      patch admin_settings_path, params: { setting: { organization_id: organization.id, invoice_prefix: "AWBW" } }

      expect(response).to redirect_to(admin_settings_path)
      expect(response).to have_http_status(:see_other)
      expect(Setting.count).to eq(1)
      expect(Setting.app_organization).to eq(organization)
      expect(Setting.invoice_prefix).to eq("AWBW")
    end

    it "points the row at the chosen return and remittance addresses" do
      organization = create(:organization)
      Setting.create!(organization: organization)
      return_address = create(:address, addressable: organization)
      remittance_address = create(:address, addressable: organization)

      patch admin_settings_path, params: { setting: { return_address_id: return_address.id,
                                                       remittance_address_id: remittance_address.id } }

      expect(response).to have_http_status(:see_other)
      expect(Setting.current.return_address).to eq(return_address)
      expect(Setting.current.remittance_address).to eq(remittance_address)
    end

    it "names who signs CE certificates" do
      administrator = create(:person)

      patch admin_settings_path, params: { setting: { ce_administrator_id: administrator.id } }

      expect(response).to have_http_status(:see_other)
      expect(Setting.ce_administrator).to eq(administrator)
    end

    it "names who an import credits when its source names no one" do
      user = create(:user)

      patch admin_settings_path, params: { setting: { import_user_id: user.id } }

      expect(response).to have_http_status(:see_other)
      expect(Setting.import_user).to eq(user)
    end

    it "saves the attention line shown on the contact page" do
      patch admin_settings_path, params: { setting: { contact_attention: "Front Desk, Operations" } }

      expect(response).to redirect_to(admin_settings_path)
      expect(Setting.contact_attention).to eq("Front Desk, Operations")
    end

    it "re-renders with errors on a malformed email" do
      patch admin_settings_path, params: { setting: { info_email: "nope" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(Setting.count).to eq(0)
    end
  end
end
