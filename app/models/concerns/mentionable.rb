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

  # Records of klass linked to this one by a rich-text mention in either direction.
  def connected_records(klass)
    mentions = ActionTextMention.joins(:action_text_rich_text)
    mentioning = mentions.where(mentionable: self, action_text_rich_texts: { record_type: klass.polymorphic_name })
    mentioned = mentions.where(
      mentionable_type: klass.polymorphic_name,
      action_text_rich_texts: { record_type: self.class.polymorphic_name, record_id: id }
    )
    klass.where(id: mentioning.select("action_text_rich_texts.record_id"))
      .or(klass.where(id: mentioned.select(:mentionable_id)))
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
