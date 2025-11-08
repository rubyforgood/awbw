class ProjectUsersController < ApplicationController
  def destroy
    project_user = ProjectUser.find(params[:id])
    user = project_user.user

    if project_user.destroy
      flash[:notice] = 'Project user has been deleted.'
    else
      flash[:alert] = 'Unable to delete project user.  Please contact AWBW.'
    end
    redirect_to generate_facilitator_user_path(user)
  end
end
