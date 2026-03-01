require "rails_helper"

RSpec.describe "Organization sector displays", type: :system do
  let!(:organization) do
    direct_sector_1 = create(:sector, name: "Direct Sector 1")
    direct_sector_2 = create(:sector, name: "Direct Sector 2")
    affiliated_sector_1 = create(:sector, name: "Affiliated Sector 1")
    affiliated_sector_2 = create(:sector, name: "Affiliated Sector 2")

    person_1 = create(:person)
    person_2 = create(:person)

    create(:sectorable_item, sector: affiliated_sector_1, sectorable: person_1)
    create(:sectorable_item, sector: affiliated_sector_2, sectorable: person_2)

    org = create(
      :organization,
      organization_status: create(:organization_status, name: "Active")
    )

    create(:sectorable_item, sector: direct_sector_1, sectorable: org)
    create(:sectorable_item, sector: direct_sector_2, sectorable: org)

    create(:affiliation, organization: org, person: person_1, position: :default)
    create(:affiliation, organization: org, person: person_2, position: :default)

    org
  end

  let(:user) { create(:user, :admin) }

  before do
    sign_in user
  end

  context "organization show page" do
    it "displays sectors with truncation when there are more than 3" do
      visit organization_path(organization)

      expect(page).to have_content(organization.name)
      expect(page).to have_content("Sectors")

      all_sector_names = organization.all_sectors.map(&:name).sort

      if all_sector_names.length > 3
        all_sector_names.first(3).each do |sector_name|
          expect(page).to have_content(sector_name)
        end

        expect(page).not_to have_content(all_sector_names[3])

        expect(page).to have_content(/\+?[0-9]+ more|\.\.\./i)
      else
        all_sector_names.each do |sector_name|
          expect(page).to have_content(sector_name)
        end
      end
    end
  end

  context "population served page" do
    it "displays all sectors with correct counts for affiliated sectors only" do
      visit populations_served_organization_path(organization)

      expect(page).to have_content("Sector Distribution")
      expect(page).to have_content(organization.name)
      expect(page).to have_content("Sectors")

      all_sector_names = organization.all_sectors.map(&:name).sort

      all_sector_names.each do |sector_name|
        expect(page).to have_content(sector_name)
      end

      people = organization.users.includes(person: :sectors).map(&:person).compact

      expected_counts = Hash.new(0)
      people.each do |person|
        primary_sector = person.sectors.first
        expected_counts[primary_sector.name] += 1 if primary_sector
      end

      expected_counts.each do |sector_name, count|
        expected_text = "#{count} #{count == 1 ? 'person' : 'people'}"
        expect(page).to have_content(expected_text)
      end
    end
  end
end
