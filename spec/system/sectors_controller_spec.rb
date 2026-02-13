require 'rails_helper'

RSpec.describe SectorsController, type: :system do
    describe "#index" do
      let!(:admin) { create(:user, :admin) }

      before do
        sign_in(admin)
      end

      subject { visit sectors_path(params) }

      let!(:sectors) do
        [
          create(:sector, name: "Sector1", published: true),
          create(:sector, name: "Sector2", published: true),
          create(:sector, name: "Sector3", published: false),
          create(:sector, name: "Sector4", published: false)
        ]
      end

      context "without filters" do
        let(:params) { {} }

        it "returns all sectors" do
          subject
          within "table" do
            sectors.each do |sector|
              expect(page).to have_content(sector.name)
              expect(page).to have_content(sector.published ? "Yes" : "No")
            end
          end
        end
      end

      context "with published filter" do
        let(:params) { { published: "true" } }
        let(:published_sectors) { sectors.select(&:published) }

        it "returns only published sectors" do
          subject
          within "table" do
            sectors.select(&:published).each do |sector|
              expect(page).to have_content(sector.name)
              expect(page).to have_content("Yes")
            end
            expect(page).to have_css('table tbody tr', count: published_sectors.size)
          end
        end
      end

      context "with unpublished filter" do
        let(:params) { { published: "false" } }
        let(:unpublished_sectors) { sectors.reject(&:published) }

        it "returns only unpublished sectors" do
          subject
          within "table" do
            sectors.reject(&:published).each do |sector|
              expect(page).to have_content(sector.name)
              expect(page).to have_content("No")
            end
            expect(page).to have_css('table tbody tr', count: unpublished_sectors.size)
          end
        end
      end

      context "with name filter" do
        let(:params) { { sector_name: "Sector1" } }

        it "returns sectors matching the name filter" do
          subject
          within "table" do
            expect(page).to have_content("Sector1")
            expect(page).not_to have_content("Sector2")
            expect(page).not_to have_content("Sector3")
            expect(page).not_to have_content("Sector4")
          end
        end
      end
    end
  end
