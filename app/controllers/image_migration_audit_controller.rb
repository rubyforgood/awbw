# app/controllers/image_migration_audit_controller.rb
class ImageMigrationAuditController < ApplicationController
	include Rails.application.routes.url_helpers

	def index
		@results = []

		# -----------------------------------------------------------------
		# Configure models to audit
		# -----------------------------------------------------------------
		audit(User,
					as: [:avatar],
					paperclip: [:avatar]
		)

		audit(Workshop, # includes WorkshopIdea
					as: [:thumbnail, :header, :images, :attachments],
					paperclip: [:thumbnail, :header]
		)

		audit(Resource,
					as: [:attachments, :images],
					paperclip: []
		)

		audit(WorkshopLog,
					as: [:media_files],
					paperclip: []
		)

		audit(Report,
					as: [:image, :form_file, :images, :media_files],
					paperclip: [:image, :form_file]
		)



		# audit(
		# 	Attachment,
		# 	as_associations: [:file],
		# 	paperclip_groups: [:file]
		# )
		# audit(
		# 	Image,
		# 	as_associations: [:file],
		# 	paperclip_groups: [:file]
		# )
		# audit(
		# 	MediaFile,
		# 	as_associations: [:file],
		# 	paperclip_groups: [:file]
		# )

		# -----------------------------------------------------------------
		# Filter only records that actually have data
		# -----------------------------------------------------------------
		@results.select! do |row|
			row[:attachments].any? do |att|
				paperclip_present?(att[:paperclip]) ||
					att.dig(:activestorage, :urls).present?
			end
		end
	end

	private

	# ==================================================================
	# MAIN DRIVER
	# ==================================================================
	def audit(klass, as:, paperclip:)
		return unless klass.table_exists?

		eager = eager_for(klass, as, paperclip)

		klass.includes(*eager).find_each do |record|
			rows = attachment_rows_for(record, as, paperclip)

			@results << {
				model: klass.name,
				id: record.id,
				attachments: rows
			}
		end
	end

	# ==================================================================
	# Eager loading builder
	# ==================================================================
	def eager_for(klass, as_associations, paperclip_groups)
		reflections = klass.reflect_on_all_associations.index_by(&:name)
		eager = []

		as_associations.each do |name|
			if paperclip_groups.include?(name)
				# Singular Paperclip migrated → ActiveStorage
				att  = "#{name}_attachment".to_sym
				blob = "#{name}_blob".to_sym
				eager << att  if reflections.key?(att)
				eager << blob if reflections.key?(blob)
			else
				# Plural / wrapper model (images, media_files, attachments)
				if reflections.key?(name)
					eager << { name => [:file_attachment, :file_blob] }
				end
			end
		end

		eager.uniq
	end

	# ==================================================================
	# Build all rows for a given record
	# ==================================================================
	def attachment_rows_for(record, as_associations, paperclip_groups)
		pclip = extract_paperclip_groups(record, paperclip_groups)
		rows  = []

		as_associations.each do |assoc|
			value = safe_send(record, assoc)

			if value.respond_to?(:attached?)
				# has_one_attached
				rows << row_for(record, assoc, pclip[assoc], value)

			elsif value.respond_to?(:to_ary)
				# has_many_attached or wrapper-multiple
				Array(value).each_with_index do |item, i|
					rows << row_for(record, "#{assoc}[#{i}]", nil, item.try(:file))
				end

			else
				# No AS, but maybe Paperclip exists
				rows << row_for(record, assoc, pclip[assoc], nil)
			end
		end

		# Add Paperclip-only groups
		(paperclip_groups - as_associations).each do |group|
			rows << row_for(record, group, pclip[group], nil)
		end

		rows
	end

	# ==================================================================
	# Build a single table row
	# ==================================================================
	def row_for(_record, name, paperclip_data, attachment_or_item)
		{
			name: name.to_s,
			paperclip: paperclip_data || {},
			activestorage: extract_as_info(attachment_or_item)
		}
	end

	# ==================================================================
	# PAPERCLIP data extractor
	# ==================================================================
	def extract_paperclip_groups(record, groups)
		attrs = record.attributes

		groups.each_with_object({}) do |group, hash|
			prefix = group.to_s
			data = {}

			attrs.each do |col, val|
				if col.start_with?("#{prefix}_")
					data[col] = val
				end
			end

			hash[group] = data if data.any?
		end
	end

	# ==================================================================
	# ACTIVE STORAGE info extractor
	# ==================================================================
	def extract_as_info(attachment_or_item)
		return {} if attachment_or_item.nil?

		# has_one_attached / has_many_attached
		if attachment_or_item.respond_to?(:attached?)
			if attachment_or_item.attached?
				urls = if attachment_or_item.respond_to?(:each)
								 attachment_or_item.map { |att| safe_url_for(att) }.compact
							 else
								 Array.wrap(safe_url_for(attachment_or_item)).compact
							 end
				return { attached: true, urls: urls }
			else
				return { attached: false, urls: [] }
			end
		end

		# wrapper model with .file
		if attachment_or_item.respond_to?(:file) &&
			attachment_or_item.file.respond_to?(:attached?)
			file = attachment_or_item.file
			if file.attached?
				return { attached: true, urls: Array.wrap(safe_url_for(file)).compact }
			else
				return { attached: false, urls: [] }
			end
		end

		{}
	rescue => e
		{ error: e.class.name, message: e.message }
	end

	# ==================================================================
	# Helpers
	# ==================================================================
	def paperclip_present?(data)
		data.present? && data.values.any?(&:present?)
	end

	def safe_send(record, method)
		record.public_send(method)
	rescue NoMethodError
		nil
	end

	def safe_url_for(att)
		url_for(att)
	rescue => e
		Rails.logger.debug("[ImageMigrationAudit] url_for failed: #{e.class}: #{e.message}")
		nil
	end
end
