class Footer < ApplicationRecord

  def self.phone
    first.phone
  end

  def self.general_questions
    first.general_questions
  end
end
