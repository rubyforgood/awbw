# Reshapes age ranges to mirror sectors: the "primary age range" question becomes
# a single-select dropdown (one primary), the "additional ages served" question
# stays multi-select. Also renames both to the new labels and normalizes any
# existing data that marked more than one primary age range down to one.
class MakePrimaryAgeGroupSingleSelect < ActiveRecord::Migration[8.1]
  def up
    return unless table_exists?(:form_fields)

    FormField.reset_column_information

    FormField.where(field_identifier: "primary_age_group").find_each do |field|
      field.update!(answer_type: :single_select_dropdown, name: "Primary age range")
    end
    FormField.where(field_identifier: "additional_age_group").find_each do |field|
      field.update!(name: "Additional ages served")
    end

    normalize_primary_age_groups
  end

  def down
    return unless table_exists?(:form_fields)

    FormField.reset_column_information

    FormField.where(field_identifier: "primary_age_group").find_each do |field|
      field.update!(answer_type: :multi_select_checkbox, name: "Primary Age Group(s) Served")
    end
    FormField.where(field_identifier: "additional_age_group").find_each do |field|
      field.update!(name: "Additional Age Group(s) Served")
    end
  end

  # Keep one primary age range per owner (the first by category position/name),
  # demoting the rest so the new single-primary rule holds for existing data.
  def normalize_primary_age_groups
    CategorizableItem
      .joins(category: :category_type)
      .where(category_types: { name: "AgeRange" }, is_primary: true)
      .includes(category: :category_type)
      .group_by { |item| [ item.categorizable_type, item.categorizable_id ] }
      .each_value do |items|
        next if items.size <= 1

        items.sort_by { |item| [ item.category&.position || 0, item.category&.name.to_s ] }
             .drop(1)
             .each { |item| item.update_columns(is_primary: false) }
      end
  end
end
