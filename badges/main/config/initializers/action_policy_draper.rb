Rails.application.config.to_prepare do
  module ActionPolicy
    module DraperSupport
      def lookup(record, *args, **kwargs)
        record = record.object if record.is_a?(::Draper::Decorator)
        super
      end
    end
  end

  ActionPolicy.singleton_class.prepend(ActionPolicy::DraperSupport)
end
