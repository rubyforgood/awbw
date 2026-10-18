# One question as a respondent saw it: a form field, or one fanned-out copy of
# it asked about a linked resource. A copy's answers keep a nil form_field, so
# they're found by the sentence they were asked under, within the field's form.
class FormQuestion
  attr_reader :field, :resource

  # Every question a field asks: the field itself, or one copy per linked resource.
  def self.for_field(field)
    return [ new(field) ] unless field.per_resource?

    field.form_field_resources.filter_map(&:resource).map { |resource| new(field, resource) }
  end

  # The question a results-card link names by id, or nil when either id is stale.
  def self.find(form_field_id, resource_id = nil)
    field = FormField.find_by(id: form_field_id)
    return unless field
    return new(field) if resource_id.blank?

    resource = Resource.find_by(id: resource_id)
    new(field, resource) if resource
  end

  def initialize(field, resource = nil)
    @field = field
    @resource = resource
  end

  def label
    @resource ? @field.per_resource_question(@resource) : @field.name
  end

  def answers
    return FormAnswer.where(form_field: @field) unless @resource

    FormAnswer.where(form_field: nil, question_name_when_answered: label,
      form_submission_id: FormSubmission.where(form_id: @field.form_id).select(:id))
  end
end
