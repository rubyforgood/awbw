module Analytics
	class AhoyTracker
		class << self

			# Core API
			def track(controller, action, resource)
				return unless resource.present?

				case action.to_sym
				when :view, :print, :download
					track_interaction(controller, action, resource)
				when :create, :update, :destroy
					track_record_change(controller, action, resource)
				else
					raise ArgumentError, "Unknown tracking action: #{action}"
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

			def format_changes(changes)
				changes.each_with_object({}) do |(attr, (before, after)), h|
					h[attr] = { before: before, after: after }
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
		end
	end
end
