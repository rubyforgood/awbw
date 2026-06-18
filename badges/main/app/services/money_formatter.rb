# Centralizes how a cents amount renders as currency so models, helpers, and
# decorators all format money the same way. Every method takes integer cents.
# View code should call the `dollars_from_cents` helper, which delegates here;
# models and other POROs (no view-helper access) call MoneyFormatter directly.
class MoneyFormatter
  # Full amount with a thousands delimiter, dropping the cents when the amount is
  # a whole number of dollars: 150000 => "$1,500", 75050 => "$750.50".
  def self.dollars_from_cents(cents)
    cents = cents.to_i
    precision = (cents % 100).zero? ? 0 : 2
    ActiveSupport::NumberHelper.number_to_currency(cents / 100.0, precision: precision)
  end

  # Abbreviated for tight UI like the grant picker: plain under $1k ("$750"),
  # "k" for thousands ("$12.5k"), "m" for millions ("$1.2m"). One decimal place,
  # trailing .0 dropped. Lossy on purpose — use dollars_from_cents for exact values.
  def self.compact_from_cents(cents)
    amount = cents.to_i.to_d / 100
    if amount >= 1_000_000
      "$#{trim_decimal(amount / 1_000_000)}m"
    elsif amount >= 1_000
      "$#{trim_decimal(amount / 1_000)}k"
    else
      "$#{amount.to_i}"
    end
  end

  def self.trim_decimal(value)
    rounded = value.round(1)
    rounded.frac.zero? ? rounded.to_i.to_s : rounded.to_s("F")
  end
  private_class_method :trim_decimal
end
