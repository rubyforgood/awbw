class OrganizationUsersController < ApplicationController
  def destroy
    organization_user = OrganizationUser.find(params[:id])
    user = organization_user.user

    if organization_user.destroy
      flash[:notice] = "Organization user has been deleted."
    else
      flash[:alert] = "Unable to delete organization user.  Please contact AWBW."
    end
    redirect_to generate_facilitator_user_path(user)
  end
end
