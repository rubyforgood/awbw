# frozen_string_literal: true

class PersonFromUserService
  attr_reader :user, :person

  def initialize(user:)
    @user = user
    @person = Person.new
  end

  def call
    hydrate_person
    hydrate_addresses
    hydrate_contact_methods
    hydrate_organizations
    person
  end

    private

  def hydrate_person
    person.assign_attributes(
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email,
      email_type: user.email_type,
      best_time_to_call: user.best_time_to_call,
      date_of_birth: user.birthday,
      notes: user.notes,
    )
  end

  def hydrate_organizations
    # t.integer "agency_id"
  end

  def hydrate_contact_methods
    person.contact_methods.build(
      kind: :phone,
      value: user.phone,
      primary: true
    ) if user.phone.present?
    person.contact_methods.build(
      kind: :phone,
      value: user.phone2,
      ) if user.phone2.present?
    person.contact_methods.build(
      kind: :phone,
      value: user.phone3,
      ) if user.phone3.present?
  end

  def hydrate_addresses
    # t.integer "primary_address"

    person.addresses.build(
      address_type: nil,
      street_address: user.address,
      city: user.city,
      state: user.state,
      zip_code: user.zip,
    )
    person.addresses.build(
      address_type: nil,
      street_address: user.address2,
      city: user.city2,
      state: user.state2,
      zip_code: user.zip2,
    )
end
end
