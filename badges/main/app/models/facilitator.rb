class Facilitator < ApplicationRecord
  has_one :user

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true
end
