class OrganizationUsersController < ApplicationController
  before_action :set_organization_user, only: %i[ destroy ]

  def destroy
    authorize! @organization_user, to: :destroy?
    organization_user = OrganizationUser.find(params[:id])
    user = organization_user.user
    destroyed = organization_user.destroy

    if destroyed
      flash.now[:notice] = "Person has been removed from the organization."
    else
      flash.now[:alert] = "Unable to remove organization user. Please contact AWBW."
    end

    respond_to do |format|
      format.turbo_stream do
        if destroyed
          render :destroy
        else
          render turbo_stream: turbo_stream.replace("flash_now", partial: "shared/flash_messages"),
                 status: :unprocessable_entity
        end
      end
      format.html do
        redirect_to generate_facilitator_user_path(user)
      end
    end
  end

  private

  def set_organization_user
    @organization_user = OrganizationUser.find(params[:id])
  end
end
