# Centralizes how a plain number renders without insignificant trailing zeros, so
# models, services, helpers, and decorators all format the same way (e.g. CE hours:
# 6.0 => "6", 1.5 => "1.5", 0.25 => "0.25"). View code should call the
# `plain_number` helper, which delegates here; models and other POROs (no
# view-helper access) call NumberFormatter directly. Mirrors MoneyFormatter.
class NumberFormatter
  # The number as a string with trailing zeros dropped. Nil for a blank input so
  # callers can render their own placeholder.
  def self.plain(number)
    return if number.blank?

    value = number.to_f
    value == value.to_i ? value.to_i.to_s : value.to_s
  end
end
