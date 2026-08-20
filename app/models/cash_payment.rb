class CashPayment < Payment
  before_validation :clear_check_only_fields

  private

  def clear_check_only_fields
    self.check_number = nil
    self.memo = nil
  end
end
