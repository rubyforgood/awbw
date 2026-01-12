module ActionText
  class MentionableRegistry
    mattr_accessor :models
    self.models = %w[Workshop] # List all mentionable models


    def self.registered_models
      models.map { |name| name.constantize }
    end
  end
end
