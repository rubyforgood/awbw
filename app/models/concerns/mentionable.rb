module Mentionable
  extend ActiveSupport::Concern

  included do
  end

  class_methods do
    # Override this method in models to specify which rich text fields to check
    # Default to empty array - models must override this
    def mentionable_rich_text_fields
      []
    end
  end

  def mentionee_records_grouped
    rich_text_fields = self.class.mentionable_rich_text_fields

    result = {}

    rich_text_fields.each do |field|
      rich_text = send(field)
      next unless rich_text

      mentions = ActionTextMention.where(action_text_rich_text_id: rich_text.id)
      mentions.each do |mention|
        mentionable_type = mention.mentionable_type
        mentionable_id = mention.mentionable_id

        result[mentionable_type] ||= []

        begin
          mentionable = mentionable_type.constantize.find(mentionable_id)
          result[mentionable_type] << mentionable unless result[mentionable_type].include?(mentionable)
        rescue ActiveRecord::RecordNotFound, NameError
          next
        end
      end
    end

    result
  end

  def mentioner_records_grouped
    records = ActionTextMention
      .where(mentionable_type: self.class.name, mentionable_id: id)
      .includes(action_text_rich_text: :record)
      .map(&:action_text_rich_text)
      .map(&:record)
      .select(&:persisted?)
      .uniq

    records.group_by { |record| record.class.name }
  end
end
