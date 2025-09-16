class Facilitator < ApplicationRecord
  has_one :user
  has_many :facilitator_organizations, dependent: :restrict_with_exception
  has_many :organizations, through: :facilitator_organizations

  CONTACT_TYPES = ["Work", "Personal"].freeze
  PERMITTED_PARAMS = [
    :first_name, :last_name, :primary_email_address, :primary_email_address_type, 
    :street_address, :city, :state, :zip, :country, :mailing_address_type,
    :phone_number, :phone_number_type
  ].freeze
  
  validates :first_name, 
            :last_name, 
            :primary_email_address, 
            :primary_email_address_type, 
            :street_address, 
            :city,
            :state,
            :zip,
            :country,
            :mailing_address_type,
            :phone_number,
            :phone_number_type,
            presence: true

  validates :primary_email_address_type, inclusion: {in: CONTACT_TYPES}
  validates :mailing_address_type, inclusion: {in: CONTACT_TYPES}
  validates :phone_number_type, inclusion: {in: CONTACT_TYPES}

  # TODO: add validation for zip code containing only numbers
  # TODO: add validation on STATE
  # TODO: add validation on phone number type
end
