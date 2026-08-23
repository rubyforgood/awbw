require "rails_helper"

RSpec.describe "Organizations change log", type: :request do
  before { sign_in create(:user, :admin) }

  it_behaves_like "a page with a change log" do
    let(:record) { create(:organization) }
    let(:page_path) { edit_organization_path(record) }
  end
end
