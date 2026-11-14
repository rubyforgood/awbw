class CheckPayment < Payment
  CHECK_NUMBER_FORMAT = /\A\d+(-\d+)*\z/

  normalizes :check_number, with: ->(number) { number.strip }

  validates :check_number, presence: true
  # Checked on change so numbers already on file in other formats stay saveable.
  validates :check_number, format: { with: CHECK_NUMBER_FORMAT, message: "can only contain digits and hyphens (e.g. 53-0633995)" },
                           if: -> { check_number.present? && check_number_changed? }
end
