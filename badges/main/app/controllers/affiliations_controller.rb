class AffiliationsController < ApplicationController
  before_action :set_affiliation, only: %i[ destroy update ]

  # Inline title edit from the event-registration org-link editor.
  def update
    authorize! @affiliation, to: :update?
    updated = @affiliation.update(affiliation_params)
    notice = updated ? "Affiliation title updated." : nil
    alert = updated ? nil : "Could not update the affiliation title."

    if params[:event_registration_id].present?
      redirect_to link_organization_event_registration_path(params[:event_registration_id], return_to: params[:return_to].presence),
                  notice: notice, alert: alert
    else
      redirect_back fallback_location: root_path, notice: notice, alert: alert
    end
  end

  def destroy
    authorize! @affiliation, to: :destroy?
    affiliation = Affiliation.find(params[:id])
    person = affiliation.person
    destroyed = affiliation.destroy

    if destroyed
      flash.now[:notice] = "Person has been removed from the organization."
    else
      flash.now[:alert] = "Unable to remove affiliation. Please contact AWBW."
    end

    respond_to do |format|
      format.turbo_stream do
        if destroyed
          render turbo_stream: turbo_stream.remove("affiliation_#{affiliation.id}")
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

  def set_affiliation
    @affiliation = Affiliation.find(params[:id])
  end

  def affiliation_params
    params.require(:affiliation).permit(:title)
  end
end
