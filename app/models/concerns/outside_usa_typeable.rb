# Pairs a state attribute with the `<attribute>_outside_usa` box from
# shared/_state_select. A typed value wins over the dropdown whichever one params
# assign first, and writes straight to the column so nested autosave sees the change.
module OutsideUsaTypeable
  extend ActiveSupport::Concern

  class_methods do
    def typed_outside_usa(attribute)
      typed = :"#{attribute}#{OutsideUsaState::SUFFIX}"
      attr_reader typed

      define_method(:"#{typed}=") do |value|
        instance_variable_set(:"@#{typed}", value.to_s.strip.presence)
        public_send(:"#{attribute}=", public_send(attribute))
      end

      define_method(:"#{attribute}=") do |value|
        super(OutsideUsaState.pick(value, public_send(typed)))
      end
    end
  end
end
