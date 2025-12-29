# frozen_string_literal: true

require "rails_helper"

RSpec.describe FacilitatorFromUserService do
  subject(:service) { described_class.new(user: user) }

  let(:user) do
    create(
      :user,
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.com",
      email_type: "work",
      best_time_to_call: "Evenings",
      birthday: Date.new(1990, 1, 1),
      notes: "Some notes",
      phone: "111-111-1111",
      phone2: "222-222-2222",
      phone3: nil,
      address: "123 Main St",
      city: "Boston",
      state: "MA",
      zip: "02101",
      address2: "456 Side St",
      city2: "Cambridge",
      state2: "MA",
      zip2: "02139"
    )
  end

  describe "#call" do
    let(:facilitator) { service.call }

    it "returns a new Facilitator" do
      expect(facilitator).to be_a(Facilitator)
      expect(facilitator).to be_new_record
    end

    it "hydrates facilitator attributes from the user" do
      expect(facilitator).to have_attributes(
                               first_name: "Jane",
                               last_name: "Doe",
                               email: "jane@example.com",
                               email_type: "work",
                               best_time_to_call: "Evenings",
                               date_of_birth: Date.new(1990, 1, 1),
                               notes: "Some notes"
                             )
    end

    it "builds contact methods from user phone fields" do
      contact_methods = facilitator.contact_methods

      expect(contact_methods.size).to eq(2)

      primary_phone = contact_methods.find(&:is_primary)
      secondary_phone = contact_methods.reject(&:is_primary).first

      expect(primary_phone).to have_attributes(
                                 kind: "phone",
                                 value: "111-111-1111",
                                 is_primary: true
                               )

      expect(secondary_phone).to have_attributes(
                                   kind: "phone",
                                   value: "222-222-2222"
                                 )
    end

    it "builds addresses from user address fields" do
      addresses = facilitator.addresses

      expect(addresses.size).to eq(2)

      expect(addresses.first).to have_attributes(
                                   street_address: "123 Main St",
                                   city: "Boston",
                                   state: "MA",
                                   zip_code: "02101"
                                 )

      expect(addresses.second).to have_attributes(
                                    street_address: "456 Side St",
                                    city: "Cambridge",
                                    state: "MA",
                                    zip_code: "02139"
                                  )
    end

    context "when optional user fields are blank" do
      let(:user) do
        create(
          :user,
          phone: nil,
          phone2: nil,
          phone3: nil,
          address2: nil,
          city2: nil,
          state2: nil,
          zip2: nil
        )
      end

      it "does not build contact methods" do
        facilitator = service.call
        expect(facilitator.contact_methods).to be_empty
      end

      it "still builds addresses (even if values are nil)" do
        facilitator = service.call
        expect(facilitator.addresses.size).to eq(2)
      end
    end
  end
end
