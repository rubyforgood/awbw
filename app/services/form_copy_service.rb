class FormCopyService
  COPY_NAME_PREFIX = "COPY of ".freeze

  def initialize(form)
    @form = form
  end

  def call
    Form.transaction do
      copy = build_form_copy
      copy.save!
      copy_fields_into(copy)
      copy
    end
  end

  private

  # A published form requires a slug, and slug is globally unique — so a copy
  # starts unpublished with no slug for the admin to set before publishing.
  # Purpose is cleared too: two forms sharing an agreement scenario would
  # double-count it, so the admin assigns the copy's scenario deliberately.
  def build_form_copy
    @form.dup.tap do |copy|
      copy.name = "#{COPY_NAME_PREFIX}#{@form.display_name}"
      copy.slug = nil
      copy.published = false
      copy.purpose = nil
    end
  end

  def copy_fields_into(copy)
    field_map = {}

    @form.form_fields.order(:position, :id).each do |field|
      new_field = field.dup
      new_field.form = copy
      new_field.save!
      field_map[field.id] = new_field

      # AnswerOptions are shared globally — re-point the join rows at the existing
      # records rather than duplicating them.
      field.form_field_answer_options.each do |ffao|
        new_field.form_field_answer_options.create!(answer_option_id: ffao.answer_option_id)
      end
    end

    remap_field_parents(field_map)
  end

  def remap_field_parents(field_map)
    field_map.each_value do |new_field|
      next if new_field.parent_id.nil?

      new_field.update!(parent_id: field_map[new_field.parent_id]&.id)
    end
  end
end
