# Public, account-free pretty-URL endpoint for a standalone, published form
# (/f/:slug). Reuses the public-registration field partials, so answers arrive
# under the shared `public_registration[form_fields]` param namespace.
class PublicFormsController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[show create thank_you]
  before_action :set_form

  def show
    authorize! @form, to: :public_show?
    @form_fields = ordered_fields
  end

  def create
    authorize! @form, to: :public_show?

    # Honeypot — a bot that fills the hidden field is silently bounced.
    if params.dig(:public_registration, :website_url).present?
      redirect_to public_form_path(@form.slug)
      return
    end

    @form_fields = ordered_fields
    form_params = merge_retained_uploads(params.dig(:public_registration, :form_fields)&.to_unsafe_h || {})

    @field_errors = validate_required_fields(form_params)
    if @field_errors.any?
      flash.now[:alert] = "Your submission is not complete yet. Scroll down to check for any errors or missing information."
      render :show, status: :unprocessable_content
      return
    end

    Current.source = "public_form"
    result = PublicFormSubmission.call(form: @form, form_params: form_params)

    if result.success?
      redirect_to thank_you_public_form_path(@form.slug), notice: "Thank you — your response has been submitted!"
    else
      flash.now[:alert] = result.errors.join(", ").presence || "Something went wrong. Please try again."
      render :show, status: :unprocessable_content
    end
  end

  def thank_you
    authorize! @form, to: :public_show?
  end

  private

  # Scoped so a draft, an event form, or an unknown slug 404s.
  def set_form
    @form = Form.standalone.published.find_by!(slug: params[:slug])
  end

  def ordered_fields
    @form.form_fields.reorder(position: :asc)
  end

  # A file input can't be repopulated, so on re-render after an error fall back to
  # the already-uploaded blob's signed id (carried in retained_uploads).
  def merge_retained_uploads(form_params)
    retained = params.dig(:public_registration, :retained_uploads)&.to_unsafe_h || {}
    return form_params if retained.blank?

    retained.each do |field_id, signed_id|
      next if signed_id.blank? || form_params[field_id].present?

      form_params[field_id] = signed_id
    end
    form_params
  end

  def validate_required_fields(form_params)
    fields = @form_fields.reject(&:group_header?)
    errors = FormAnswerValidator.call(fields, form_params)

    fields_by_identifier = fields.select { |f| f.field_identifier.present? }.index_by(&:field_identifier)
    confirm_field = fields_by_identifier["confirm_email"]
    email_field = fields_by_identifier["primary_email"]
    if confirm_field && email_field && errors[confirm_field.id].nil?
      confirm_value = form_params[confirm_field.id.to_s].to_s.strip
      email_value = form_params[email_field.id.to_s].to_s.strip
      errors[confirm_field.id] = "must match email" if confirm_value.present? && confirm_value != email_value
    end

    errors
  end
end
