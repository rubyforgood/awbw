class Permission < ApplicationRecord
  # Associations
  has_many :user_permissions
  has_many :users, through: :user_permissions

  # Methods
  def self.create_defaults
    defaults.each_with_index do |p, i|
      legacy_id = i + 1
      Permission.find_or_create_by(security_cat: p, legacy_id: legacy_id)
    end
  end

  def name
    security_cat
  end

  private

  def self.defaults
    #TODO: Add Combined Windows
    ['Guest', 'Member', 'Women\'s Windows', 'Children\'s Windows', 'Survivor\'s Art Circle']
  end
end
