namespace :user_data do
  desc "Generate People from Users"
  task generate_person: :environment do
    puts "🚀 Starting Person creation for all Users..."
    puts "Environment: #{Rails.env}"
    puts "==============================================="

    User.where(person_id: nil).each do |user|
      person = Person.where(
        first_name: user.first_name.presence || "unknown",
        last_name: user.last_name.presence || "unknown",
        email: user.email,
        # phone_number: user.phone,
        # street_address: user.address,
        # city: user.city,
        # state: user.state,
        # zip: user.zip,
        created_by_id: user.id,
        updated_by_id: user.id
      ).first_or_create!
      unless person.contact_methods.phone.exists?
        person.contact_methods.create!(
          kind: :phone,
          value: user.phone,
          is_primary: true
        ) if user.phone.present?
      end
      unless person.addresses.exists?
        person.addresses.create!(
          street_address: user.address.presence || "unknown",
          city: user.city.presence || "unknown",
          state: user.state.presence || "unknown",
          locality: (user.state != "CA" && user.state != "" ? "Outside CA" : "Unknown"),
          zip_code: user.zip,
          # is_primary: true
        ) if user.address.present? || user.city.present? || user.state.present? || user.zip.present?
      end

      user.update!(person: person)

      user.workshops.each do |workshop|
        puts workshop.name
        puts workshop.sectors.pluck(:name)
        workshop.sectors.each do |sector|
          person.sectorable_items.where(
            sector: sector,
            sectorable: person,
            sectorable_type: "Person",
            is_leader: false,
          ).first_or_create!
        end
      end
    end
  end
end
