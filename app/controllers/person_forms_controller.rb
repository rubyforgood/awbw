class PersonFormsController < ApplicationController
  def create
    authorize! :person_form, to: :create?
    @person_form = current_user.person.forms.build(person_form_params)
    if @person_form.save
      flash[:notice] = "Form successfully created"
    else
      flash[:alert] = "There was a problem saving your form."
    end
    redirect_to root_path
  end

  private

  def person_form_params
    params.require(:person_form).permit(
      :form_id,
      person_form_form_fields_attributes: [
        :text, :form_field_id
      ]
    )
  end
end
