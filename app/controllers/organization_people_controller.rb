class OrganizationPeopleController < ApplicationController
  before_action :set_organization_person, only: %i[ destroy ]

  def destroy
    authorize! @organization_person, to: :destroy?
    organization_person = OrganizationPerson.find(params[:id])
    person = organization_person.person
    destroyed = organization_person.destroy

    if destroyed
      flash.now[:notice] = "Person has been removed from the organization."
    else
      flash.now[:alert] = "Unable to remove organization person. Please contact AWBW."
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
        redirect_to generate_facilitator_user_path(person.user)
      end
    end
  end

  private

  def set_organization_person
    @organization_person = OrganizationPerson.find(params[:id])
  end
end
