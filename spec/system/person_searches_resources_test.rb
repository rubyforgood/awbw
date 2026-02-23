require 'rails_helper'

RSpec.describe "People can search for resources" do
  describe "create person and login and resources" do
    context "When user is logged in" do
      before do
        user = create(:user)
        create(:person, user: user)
        create(:resource, :published, title: "Scholarship Application Guide", featured: true, kind: "Scholarship")
        create(:resource, :published, title: "Workshop Session Template", kind: "Template")
        create(:resource, :published, title: "Participant Handout Package", kind: "Handout")
        create(:resource, :published, title: "Facilitator Toolkit Complete Set", kind: "Toolkit")
        create(:resource, :published, title: "Registration and Consent Forms", kind: "Form")
        create(:resource, :published, title: "Facilitator Resource Guide", kind: "Toolkit")
        sign_in user
        visit '/'
      end

      it "navigate to resources and see results" do
        visit resources_path

        expect(page).to have_content('Resources')
        expect(page).to have_content('KINDS (CLICK TO FILTER)')

        expect(page).to have_content('Workshop Session Template')
        expect(page).to have_content('Participant Handout Package')
        expect(page).to have_content('Facilitator Toolkit Complete Set')
        expect(page).to have_content('Registration and Consent Forms')
        expect(page).to have_content('Facilitator Resource Guide')
      end

      describe "filtering with the kinds" do
        before do
          visit resources_path
        end

        it "filter for Handouts" do
          find('label', text: 'Handouts').click
          expect(page).to have_content('Participant Handout Package')
          expect(page).to have_no_content('Scholarship Application Guide')
          expect(page).to have_no_content('Workshop Session Template')
          expect(page).to have_no_content('Facilitator Toolkit Complete Set')
          expect(page).to have_no_content('Registration and Consent Forms')
        end

        it "filter for Templates" do
          find('label', text: 'Templates').click
          expect(page).to have_content('Workshop Session Template')
          expect(page).to have_no_content('Scholarship Application Guide')
          expect(page).to have_no_content('Participant Handout Package')
          expect(page).to have_no_content('Facilitator Toolkit Complete Set')
          expect(page).to have_no_content('Registration and Consent Forms')
        end

        it "filter for Toolkits" do
          find('label', text: 'Toolkits').click
          expect(page).to have_content('Facilitator Toolkit Complete Set')
          expect(page).to have_content('Facilitator Resource Guide')
          expect(page).to have_no_content('Scholarship Application Guide')
          expect(page).to have_no_content('Workshop Session Template')
          expect(page).to have_no_content('Participant Handout Package')
          expect(page).to have_no_content('Registration and Consent Forms')
        end

        it "filter for Forms" do
          find('label', text: 'Forms').click
          expect(page).to have_content('Registration and Consent Forms')
          expect(page).to have_no_content('Scholarship Application Guide')
          expect(page).to have_no_content('Workshop Session Template')
          expect(page).to have_no_content('Participant Handout Package')
          expect(page).to have_no_content('Facilitator Toolkit Complete Set')
        end

        it "filter for multiple kinds" do
          find('label', text: 'Toolkits').click
          find('label', text: 'Forms').click
          expect(page).to have_content('Facilitator Toolkit Complete Set')
          expect(page).to have_content('Facilitator Resource Guide')
          expect(page).to have_content('Registration and Consent Forms')
          expect(page).to have_no_content('Workshop Session Template')
          expect(page).to have_no_content('Participant Handout Package')
        end

        it "clears kind buttons and keyword filter with Clear filters" do
          # Select a kind filter
          find('label', text: 'Toolkits').click
          expect(page).to have_content('Facilitator Toolkit Complete Set')
          expect(page).to have_no_content('Workshop Session Template')

          # Clear all filters
          click_link "Clear filters"

          # All resources should reappear
          expect(page).to have_content('Workshop Session Template')
          expect(page).to have_content('Facilitator Toolkit Complete Set')
          expect(page).to have_content('Participant Handout Package')
          expect(page).to have_content('Registration and Consent Forms')
          expect(page).to have_content('Facilitator Resource Guide')

          # Kind checkbox should be unchecked
          expect(find("#kind_Toolkit", visible: :all)).not_to be_checked
        end

        describe "keyword search" do
          it "searches for resource with 'Template' keyword" do
            fill_in "query", with: "Template"
            expect(page).to have_content('Workshop Session Template')
            expect(page).to have_no_content('Participant Handout Package')
            expect(page).to have_no_content('Facilitator Toolkit Complete Set')
            expect(page).to have_no_content('Registration and Consent Forms')
          end

          it "searches for resource with 'Session' keyword" do
            fill_in "query", with: "Session"
            expect(page).to have_content('Workshop Session Template')
            expect(page).to have_no_content('Scholarship Application Guide')
            expect(page).to have_no_content('Participant Handout Package')
            expect(page).to have_no_content('Facilitator Toolkit Complete Set')
            expect(page).to have_no_content('Registration and Consent Forms')
          end

          it "searches for resource with 'Handout' keyword" do
            fill_in "query", with: "Handout"
            expect(page).to have_content('Participant Handout Package')
            expect(page).to have_no_content('Scholarship Application Guide')
            expect(page).to have_no_content('Workshop Session Template')
            expect(page).to have_no_content('Facilitator Toolkit Complete Set')
            expect(page).to have_no_content('Registration and Consent Forms')
          end

          it "clears search with empty string" do
            fill_in "query", with: "Handout"
            expect(page).to have_content('Participant Handout Package')

            fill_in "query", with: ""
            expect(page).to have_content('Workshop Session Template')
            expect(page).to have_content('Participant Handout Package')
            expect(page).to have_content('Facilitator Toolkit Complete Set')
            expect(page).to have_content('Registration and Consent Forms')
          end

          it "searches for resource that doesn't exist" do
            fill_in "query", with: "NonexistentResource"
            expect(page).to have_no_content('Scholarship Application Guide')
            expect(page).to have_no_content('Workshop Session Template')
            expect(page).to have_no_content('Participant Handout Package')
            expect(page).to have_no_content('Facilitator Toolkit Complete Set')
            expect(page).to have_no_content('Registration and Consent Forms')
            expect(page).to have_content('There are no resources that match your search. Please try again.')
          end

          it "shows multiple results for partial match" do
            fill_in "query", with: "Facilitator"
            expect(page).to have_content('Facilitator Toolkit Complete Set')
            expect(page).to have_content('Facilitator Resource Guide')
            expect(page).to have_no_content('Scholarship Application Guide')
            expect(page).to have_no_content('Workshop Session Template')
            expect(page).to have_no_content('Participant Handout Package')
            expect(page).to have_no_content('Registration and Consent Forms')
          end

          it "combines keyword search with kind filter" do
            find('label', text: 'Toolkits').click
            fill_in "query", with: "Complete"
            expect(page).to have_content('Facilitator Toolkit Complete Set')
            expect(page).to have_no_content('Facilitator Resource Guide')
            expect(page).to have_no_content('Scholarship Application Guide')
            expect(page).to have_no_content('Workshop Session Template')
            expect(page).to have_no_content('Participant Handout Package')
            expect(page).to have_no_content('Registration and Consent Forms')
          end
        end

        describe "pagination testing" do
          before do
            # Create 30 resources for pagination
            30.times do |i|
              create(:resource, :published,
                title: "Test Resource #{i+1}",
                kind: [ "Toolkit", "Handout", "Template", "Form" ].sample
              )
            end
          end

          it "shows pagination" do
            visit resources_path

            #  pagination existence
            expect(page).to have_css('div.pagination.flex.justify-center.mt-6.w-full')
            expect(page).to have_css('span', text: '1')
            expect(page).to have_css('a', text: '2')
            expect(page).to have_css('a', text: '3')

            expect(page).to have_content('Test Resource')
            expect(page).to have_link('2')
          end
        end
      end
    end
  end
end
