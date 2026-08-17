class AffiliationsController < ApplicationController
  before_action :set_affiliation, only: %i[ edit update destroy ]

  def edit
    authorize! @affiliation
  end

  def update
    authorize! @affiliation
    @affiliation.assign_attributes(affiliation_params)
    @affiliation.comments.select(&:new_record?).each { |c| c.created_by = current_user; c.updated_by = current_user }
    @affiliation.comments.select { |c| c.persisted? && c.body_changed? }.each { |c| c.updated_by = current_user }

    if @affiliation.save
      redirect_to affiliation_return_path, notice: "Affiliation was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @affiliation, to: :destroy?

    if params[:return_to].present?
      if @affiliation.destroy
        redirect_to affiliation_return_path(anchor: "affiliations"),
                    notice: "Affiliation was removed.", status: :see_other
      else
        redirect_to edit_affiliation_path(@affiliation), alert: "Unable to remove affiliation."
      end
      return
    end

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
                 status: :unprocessable_content
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
    params.require(:affiliation).permit(
      :person_id, :organization_id, :title, :start_date, :end_date, :primary_contact,
      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ]
    )
  end

  # Return to whichever edit page the gear was clicked from, scrolled to the row
  # (or the affiliations section after a delete removes the row).
  def affiliation_return_path(anchor: helpers.dom_id(@affiliation))
    case params[:return_to]
    when "person"
      edit_person_path(params[:origin_id], anchor: anchor)
    when "organization"
      edit_organization_path(params[:origin_id], anchor: anchor)
    else
      edit_affiliation_path(@affiliation)
    end
  end
end
