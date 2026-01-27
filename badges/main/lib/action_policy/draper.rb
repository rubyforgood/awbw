module ActionPolicy
  module Draper
    def policy_for(record:, **opts)
      record = record.model while record.is_a?(::Draper::Decorator)
      super
    end
  end
end
