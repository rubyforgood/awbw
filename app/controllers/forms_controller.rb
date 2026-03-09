class FormsController < ApplicationController
  before_action :set_form, only: %i[show edit update destroy reorder_field reorder_fields edit_sections update_sections]

  def index
    authorize!
    @forms = Form.standalone.order(:name)
  end

  def show
    authorize! @form
    @form_fields = preview_form_fields
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

  def edit_sections
    authorize! @form
  end

  def update_sections
    authorize! @form

    sections = (params[:sections] || []).reject(&:blank?).map(&:to_sym)
    if sections.empty?
      flash.now[:alert] = "Please select at least one section."
      render :edit_sections, status: :unprocessable_content
      return
    end

    FormBuilderService.update_sections!(@form, sections)
    redirect_to edit_form_path(@form), notice: "Sections updated."
  end

  def reorder_field
    authorize! @form
    field = @form.form_fields.find(params[:field_id])
    field.update!(position: params[:position].to_i)
    head :ok
  end

  def reorder_fields
    authorize! @form
    positions = JSON.parse(request.body.read)["positions"] || []
    positions.each do |item|
      @form.form_fields.where(id: item["id"]).update_all(position: item["position"])
    end
    head :ok
  end

  private

  def set_form
    @form = Form.find(params[:id])
  end

  def preview_form_fields
    scope = @form.form_fields

    unless params[:preview_scholarship].present?
      scope = scope.where.not(visibility: :scholarship_only)
    end

    if params[:preview_logged_in].present?
      scope = scope.where.not(visibility: :logged_out_only)
    end

    if params[:preview_answered].present?
      scope = scope.where.not(visibility: :answers_on_file)
    end

    scope.reorder(position: :asc)
  end

  def form_params
    params.require(:form).permit(
      :name, :hide_answered_person_questions, :hide_answered_form_questions,
      form_fields_attributes: [
        :id, :question, :answer_type, :is_required, :instructional_hint,
        :field_key, :field_group, :position, :visibility, :one_time, :_destroy
      ]
    )
  end
end
