require 'rails_helper'

RSpec.describe "Facilitators can download resources" do
  describe "create facilitator and resources" do
    context "When user is logged in" do
      before do
        Capybara.current_session.current_window.resize_to(1920, 5000)
        user = create(:user)
        create(:facilitator, user: user)
        
        file1 = Rack::Test::UploadedFile.new(
          Rails.root.join('spec/fixtures/some_file.png'),
          'image/png'
        )
        
        file2 = Rack::Test::UploadedFile.new(
          Rails.root.join('spec/fixtures/some_file1.png'),
          'image/png'
        )
        
        file3 = Rack::Test::UploadedFile.new(
          Rails.root.join('spec/fixtures/some_file2.png'),
          'image/png'
        )
        
        @resource_with_both_assets = create(:resource, 
          title: "Scholarship Application Guide!", 
          featured: true, 
          inactive: false, 
          kind: "Template",
          primary_asset_attributes: { file: file1 },
          gallery_assets_attributes: {
            "0" => { file: file2 },
            "1" => { file: file3 }    
          }
        )
        
        @resource_with_primary_only = create(:resource, 
          title: "Workshop Session Template", 
          kind: "Template",
          primary_asset_attributes: { file: file1 }
        )
        
        @resource_without_assets = create(:resource, 
          title: "Participant Handout Package", 
          kind: "Handout"
        )
        
        sign_in user
        visit '/'
      end

      it "show and download resources on dashboard" do 
        expect(page).to have_content("Popular Resources")
        expect(page).to have_content("Scholarship Application Guide")
        expect(page).not_to have_content("Workshop Session Template")
        expect(page).not_to have_content("Participant Handout Package")
      end 

      it "allows downloading from dashboard for resources with primary assets" do 
        expect(page).to have_css("a[href='/resources/#{@resource_with_both_assets.id}/download']")
        expect(page).not_to have_css("a[href='/resources/#{@resource_with_primary_only.id}/download']")
        expect(page).not_to have_css("a[href='/resources/#{@resource_without_assets.id}/download']")

        find("a[href='/resources/#{@resource_with_both_assets.id}/download']").click
        expect(current_path).to eq("/resources/#{@resource_with_both_assets.id}/download")

        #expect(page.status_code).to eq(200)
        #expect(page).not_to have_content("Error")
        expect(page).not_to have_content("Not Found")
      end 

      it "allows downloading from the resources page" do 
        visit resources_path
        
        expect(page).to have_content("Resources")
        expect(page).to have_content("Scholarship Application Guide")
        expect(page).to have_content("Workshop Session Template")
        expect(page).to have_content("Participant Handout Package")

        expect(page).to have_css("a[href='/resources/#{@resource_with_both_assets.id}/download']")
        expect(page).to have_css("a[href='/resources/#{@resource_with_primary_only.id}/download']")
        expect(page).not_to have_css("a[href='/resources/#{@resource_without_assets.id}/download']")

        find("a[href='/resources/#{@resource_with_both_assets.id}/download']").click
        expect(current_path).to eq("/resources/#{@resource_with_both_assets.id}/download")
        
        #expect(page.status_code).to eq(200)
        #expect(page).not_to have_content("Error")
        expect(page).not_to have_content("Not Found")

        visit resources_path
        find("a[href='/resources/#{@resource_with_primary_only.id}/download']").click
        expect(current_path).to eq("/resources/#{@resource_with_primary_only.id}/download")

        #expect(page.status_code).to eq(200)
        #expect(page).not_to have_content("Error")
        expect(page).not_to have_content("Not Found")
      end 
    end
  end
end