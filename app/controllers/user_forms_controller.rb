class UserFormsController < ApplicationController
  def create
    @user_form = current_user.user_forms.build(user_form_params)
    if @user_form.save
      flash[:alert] = 'User form successfully created'
    else
      flash[:error] = 'There was a problem saving your form.'
    end
    redirect_to root_path
  end

  private

  def user_form_params
    params.require(:user_form).permit(
      :form_id,
      user_form_form_fields_attributes: [
        :text, :form_field_id
      ]
    )
  end
end
