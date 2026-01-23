# app/models/concerns/rich_text_searchable.rb
module RichTextSearchable
  extend ActiveSupport::Concern

  class_methods do
    # Returns a scope joining action_text_rich_texts for the model
    def join_rich_texts
      rich_texts = Arel::Table.new(:action_text_rich_texts)
      table = self.arel_table

      join_condition = rich_texts[:record_id].eq(table[:id])
                       .and(rich_texts[:record_type].eq(name)) # polymorphic record_type = model name

      joins(table.join(rich_texts, Arel::Nodes::InnerJoin).on(join_condition).join_sources)
    end
  end
end
