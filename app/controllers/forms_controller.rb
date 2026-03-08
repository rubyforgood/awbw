class FormsController < ApplicationController
  before_action :set_form, only: %i[show edit update destroy question_library add_questions]

  def index
    authorize!
    @forms = authorized_scope(Form.all)
               .includes(:form_fields, :events)
               .order(:name)
               .paginate(page: params[:page], per_page: 25)
  end

  def show
    authorize! @form
    @form_fields_by_group = grouped_fields
    @linked_events = @form.events.order(start_date: :desc)
  end

  def new
    authorize! Form.new
    @builders = builder_options
  end

  def create
    authorize! Form.new

    @form = case params[:builder_type]
    when "short_registration"
      ShortEventRegistrationFormBuilder.build_standalone!
    when "extended_registration"
      ExtendedEventRegistrationFormBuilder.build_standalone!
    when "scholarship_application"
      ScholarshipApplicationFormBuilder.build_standalone!
    when "generic"
      Form.create!(name: params[:form_name].presence || "New Form")
    else
      Form.create!(name: "New Form")
    end

    redirect_to edit_form_path(@form), notice: "Form was successfully created. Customize it below."
  end

  def edit
    authorize! @form
    set_form_variables
  end

  def update
    authorize! @form
    if @form.update(form_params)
      redirect_to @form, notice: "Form was successfully updated.", status: :see_other
    else
      set_form_variables
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @form
    @form.destroy!
    redirect_to forms_path, notice: "Form was successfully destroyed."
  end

  def question_library
    authorize! @form
    existing_keys = @form.form_fields.reorder(position: :asc).pluck(:field_key).compact
    scope = FormField.unscoped
              .where.not(form_id: @form.id)
              .where.not(field_key: [ nil, "" ])
    scope = scope.where.not(field_key: existing_keys) if existing_keys.any?
    @available_fields = scope.order(:field_group, :position).group_by(&:field_group)
    render layout: false
  end

  def add_questions
    authorize! @form
    source_field_ids = Array(params[:source_field_ids]).map(&:to_i)
    max_position = @form.form_fields.reorder(position: :asc).maximum(:position) || 0

    FormField.unscoped.where(id: source_field_ids).find_each do |source|
      max_position += 1
      new_field = @form.form_fields.create!(
        question: source.question,
        answer_type: source.answer_type,
        answer_datatype: source.answer_datatype,
        status: source.status,
        position: max_position,
        is_required: source.is_required,
        instructional_hint: source.instructional_hint,
        field_key: source.field_key,
        field_group: source.field_group
      )

      source.form_field_answer_options.each do |ffao|
        new_field.form_field_answer_options.create!(answer_option: ffao.answer_option)
      end
    end

    redirect_to edit_form_path(@form), notice: "Questions added successfully."
  end

  private

  def set_form
    @form = Form.find(params[:id])
  end

  def set_form_variables
    @form_fields_by_group = grouped_fields
    @field_groups = @form.form_fields.reorder(position: :asc).pluck(:field_group).compact.uniq
    @answer_type_options = FormField.answer_types.keys.map { |k| [ k.humanize, k ] }
  end

  def grouped_fields
    @form.form_fields.reorder(position: :asc).group_by(&:field_group)
  end

  def builder_options
    [
      { key: "short_registration", name: ShortEventRegistrationFormBuilder::FORM_NAME,
        description: "Contact, consent, qualitative, and scholarship fields" },
      { key: "extended_registration", name: ExtendedEventRegistrationFormBuilder::FORM_NAME,
        description: "Contact, background, professional, qualitative, scholarship, and payment fields" },
      { key: "scholarship_application", name: ScholarshipApplicationFormBuilder::FORM_NAME,
        description: "Scholarship-specific fields" },
      { key: "generic", name: "Generic Form",
        description: "Start with a blank form and add fields manually" }
    ]
  end

  def form_params
    params.require(:form).permit(
      :name,
      :scholarship_application,
      form_fields_attributes: [
        :id, :question, :answer_type, :answer_datatype,
        :status, :position, :is_required, :instructional_hint,
        :field_key, :field_group, :_destroy
      ]
    )
  end
end
