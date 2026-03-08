class FormsController < ApplicationController
  before_action :set_form, only: %i[edit update destroy reorder_field]

  def index
    authorize!
    @forms = Form.standalone.order(:name)
  end

  def new
    authorize!
  end

  def create
    authorize!

    sections = (params[:sections] || []).reject(&:blank?).map(&:to_sym)
    if sections.empty?
      flash.now[:alert] = "Please select at least one section."
      render :new, status: :unprocessable_content
      return
    end

    form = FormBuilderService.new(
      name: params[:name].presence || "New Form",
      sections: sections,
      scholarship_application: params[:scholarship_application] == "1"
    ).call

    redirect_to edit_form_path(form), notice: "Form created with #{form.form_fields.size} fields."
  end

  def edit
    authorize! @form
    @form_fields = @form.form_fields.reorder(position: :asc)
  end

  def update
    authorize! @form

    if @form.update(form_params)
      redirect_to edit_form_path(@form), notice: "Form updated."
    else
      @form_fields = @form.form_fields.reorder(position: :asc)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @form
    @form.destroy!
    redirect_to forms_path, notice: "Form deleted."
  end

  def reorder_field
    authorize! @form
    field = @form.form_fields.find(params[:field_id])
    field.update!(position: params[:position].to_i)
    head :ok
  end

  private

  def set_form
    @form = Form.find(params[:id])
  end

  def form_params
    params.require(:form).permit(
      :name, :hide_answered_person_questions, :hide_answered_form_questions,
      form_fields_attributes: [
        :id, :question, :answer_type, :is_required, :instructional_hint,
        :field_key, :field_group, :position, :_destroy
      ]
    )
  end
end
