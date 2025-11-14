namespace :user_data do
	desc "Generate Facilitators from Users"
	task generate_facilitator: :environment do
		puts "🚀 Starting Facilitator creation for all Users..."
		puts "Environment: #{Rails.env}"
		puts "==============================================="

		User.where(facilitator_id: nil).each do |user|
			facilitator = Facilitator.where(
				first_name: user.first_name,
				last_name: user.last_name,
				primary_email_address: user.email,
				phone_number: user.phone,
				street_address: user.address,
				city: user.city,
				state: user.state,
				zip: user.zip,
				created_by_id: user.id,
				updated_by_id: user.id
			).first_or_create!
			user.update!(facilitator: facilitator)

			user.workshops.each do |workshop|
				puts workshop.name
				puts workshop.sectors.pluck(:name)
				workshop.sectors.each do |sector|
					facilitator.sectorable_items.where(
						sector: sector,
						sectorable: facilitator,
						sectorable_type: "Facilitator",
						is_leader: false,
					).first_or_create!
				end
			end
		end
	end
end
