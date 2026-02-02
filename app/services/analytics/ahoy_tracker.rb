module Analytics
  class AhoyTracker
    class << self
      # Core API
      def track(controller, action, resource)
        return unless resource.present?

        resource = unwrap(resource)

        case action.to_sym
        when :view, :print, :download
          track_interaction(controller, action, resource)
        when :create, :update, :destroy
          track_record_change(controller, action, resource)
        else
          raise ArgumentError, "Unknown tracking action: #{action}"
        end
      end

      # Non-resource events (auth.*, system.*, etc.)
      def track_event(controller, name, properties = {})
        controller.ahoy.track(name, properties)
      end

      # Model-level events (no controller context)
      def track_event_from_model(name, user:)
        Ahoy::Tracker.new.track(name, user_id: user.id)
      end

      def track_index_intent(controller, resource_class, params:, result_count:)
        return unless controller.ahoy&.visit_token

        resource_name = resource_class.table_name
        cleaned = extract_search_params(params)
        return if cleaned.blank?

        properties = {
          resource_type: resource_class.name,
          result_count: result_count,
          keywords: cleaned[:keywords],
          filters: enrich_filter_names(cleaned[:filters]) # 👈 ONLY CHANGE
        }.compact

        event_types = []
        event_types << "search" if cleaned[:keywords].present?
        event_types << "filter" if cleaned[:filters].present?
        event_types.each do |type|
          controller.ahoy.track("#{type}.#{resource_name}", properties)
        end

        if cleaned[:keywords].present? && result_count.zero?
          controller.ahoy.track("search_zero.#{resource_name}", properties)
        end
      end

      private

      # ------------------------------
      # INTERACTION EVENTS
      # ------------------------------
      def track_interaction(controller, action, resource)
        return if already_tracked?(controller, action, resource)

        controller.ahoy.track(
          "#{action}.#{resource_name(resource)}",
          base_properties(resource)
        )
      end

      # ------------------------------
      # CREATE / UPDATE / DESTROY
      # ------------------------------
      def track_record_change(controller, action, resource)
        properties = base_properties(resource)

        case action.to_sym
        when :create
          properties[:snapshot] = snapshot_attributes(resource)

        when :update
          changes = resource.previous_changes
                            .except("updated_at", "created_at", "body", "content", "metadata")
                            .select { |attr, _| safe_for_tracking?(attr) }
          properties[:changes] = format_changes(changes) if changes.present?

        when :destroy
          properties[:snapshot] = snapshot_attributes(resource)
        end

        controller.ahoy.track(
          "#{action}.#{resource_name(resource)}",
          properties
        )
      end

      # ------------------------------
      # DEDUPING
      # ------------------------------
      def already_tracked?(controller, action, resource)
        # ---- TEST ENV (no ahoy cookies) ----
        if Rails.env.test? && defined?(RSpec)
          store = controller.instance_variable_get(:@_ahoy_request_store) || {}
          store[action] ||= Set.new
          return true if store[action].include?(resource.id)

          store[action] << resource.id
          controller.instance_variable_set(:@_ahoy_request_store, store)
          return false
        end

        # ---- REAL VISIT ----
        return false unless controller.ahoy&.visit_token

        Ahoy::Event.joins(:visit).where(
          name: "#{action}.#{resource_name(resource)}",
          ahoy_visits: { visit_token: controller.ahoy.visit_token },
          resource_id: resource.id
        ).exists?
      end

      # ------------------------------
      # HELPERS
      # ------------------------------
      def base_properties(resource)
        {
          resource_type: resource.class.name,
          resource_id: resource.id,
          resource_title: resource.decorate.title
        }
      end

      def enrich_filter_names(filters)
        return {} if filters.blank?

        filters.each_with_object({}) do |(key, raw_value), enriched|
          ids = normalize_ids(raw_value)
          next if ids.empty?

          case key.to_s
          when "categories"
            categories = Category.where(id: ids).includes(:category_type)
            enriched[:categories] = categories.map do |c|
              { id: c.id, name: c.name, type: c.category_type&.name }
            end
          when "sectors"
            enriched[:sectors] = Sector.where(id: ids).pluck(:id, :name)
                                       .map { |id, name| { id:, name: } }
          when "windows_type", "windows_type_id", "windows_type_ids", "windows_types"
            enriched[:windows_types] = WindowsType.where(id: ids).pluck(:id, :name)
                                                  .map { |id, name| { id:, name: } }
          when "kind"
            enriched[:kind] = ids
          else
            enriched[key] = ids
          end
        end
      end

      def enrich_records(klass, ids)
        return if ids.blank?

        klass.where(id: ids).pluck(:id, :name).map do |id, name|
          { id: id, name: name }
        end
      end

      def extract_search_params(params)
        return {} unless params
        raw = params.to_unsafe_h

        keywords = {
          title: raw["title"].presence,
          author: raw["author_name"].presence,
          full_text: raw["query"].presence
        }.compact

        filters = {}

        # ---- RESOURCE KIND BUTTONS ----
        filters[:kind] = Array(raw["kind"]).presence ||
          Array(raw["kinds"]).presence ||
          Array(raw["resource_kind"]).presence

        # ---- OTHER FILTERS ----
        filters[:categories]   = raw["category_ids"]   if raw["category_ids"].present?
        filters[:sectors]      = raw["sector_ids"]     if raw["sector_ids"].present?
        filters[:windows_type] = raw["windows_type_ids"] if raw["windows_type_ids"].present?

        filters.compact!

        { keywords:, filters: }.compact_blank
      end

      def format_changes(changes)
        changes.each_with_object({}) do |(attr, (before, after)), h|
          h[attr] = { before: before, after: after }
        end
      end

      def normalize_ids(value)
        case value
        when nil then []
        when String, Integer then [value.to_s]
        when Array then value.map(&:to_s)
        when Hash then value.keys.map(&:to_s)
        else []
        end
      end

      def resource_name(resource)
        resource.class.table_name.singularize
      end

      def snapshot_attributes(resource)
        resource.attributes
                .except("updated_at", "created_at")
                .select { |attr, _| safe_for_tracking?(attr) }
      end

      def safe_for_tracking?(attribute)
        !attribute.match?(/password|token|secret|key|digest|salt|otp/i)
      end

      def unwrap(resource)
        resource.respond_to?(:object) ? resource.object : resource
      end
    end
  end
end
