class Location < ApplicationRecord # TODO remove this class if unused
  has_many :events, dependent: :nullify
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  # Validations
  validates_presence_of :city, :country

  def name
    "#{city}, #{state}"
  end
end
