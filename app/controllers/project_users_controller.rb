class ProjectUsersController < ApplicationController
  def destroy
    project_user = ProjectUser.find(params[:id])
    user = project_user.user

    if project_user.destroy
      flash[:alert] = 'Project user has been deleted.'
    else
      flash[:error] = 'Unable to delete project user.  Please contact AWBW.'
    end
    redirect_to user_path(user)
  end
end
