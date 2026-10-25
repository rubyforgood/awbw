# Resolves a state submitted through shared/_state_select: the "Outside USA?" box's
# typed value when filled, otherwise the US-state dropdown's pick.
module OutsideUsaState
  SUFFIX = "_outside_usa"

  def self.pick(dropdown, typed)
    typed.to_s.strip.presence || dropdown
  end

  # A form's answers, keyed by field id (or field id → resource id for fanned-out
  # fields), with each state typed under `form_fields_outside_usa` laid over its dropdown.
  def self.form_field_answers(params, scope)
    answers = params.dig(scope, :form_fields)&.to_unsafe_h || {}
    typed = params.dig(scope, :"form_fields#{SUFFIX}")&.to_unsafe_h || {}
    answers.deep_merge(filled(typed))
  end

  def self.filled(typed)
    typed.each_with_object({}) do |(key, value), result|
      value = value.is_a?(Hash) ? filled(value) : value.to_s.strip
      result[key] = value if value.present?
    end
  end
  private_class_method :filled
end
