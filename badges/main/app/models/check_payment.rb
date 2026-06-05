class CheckPayment < Payment
  validates :check_number, presence: true
end
