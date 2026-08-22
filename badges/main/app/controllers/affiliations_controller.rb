class AffiliationsController < ApplicationController
  before_action :set_affiliation, only: %i[ edit update destroy ]
  before_action :set_registration_choices, only: %i[ edit update ]

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

  # The registration picker offers this person's own registrations, newest event
  # first, plus the currently-linked one even if it belongs to someone else (so an
  # existing link never silently drops out of the options).
  def set_registration_choices
    ids = EventRegistration.where(registrant_id: @affiliation.person_id).ids
    ids |= [ @affiliation.event_registration_id ].compact
    @registration_choices = EventRegistration
      .where(id: ids)
      .includes(:event, :organizations)
      .references(:event)
      .order(Arel.sql("events.start_date DESC"))
  end

  def affiliation_params
    params.require(:affiliation).permit(
      :person_id, :organization_id, :title, :start_date, :end_date, :primary_contact,
      :organization_address_id, :filemaker_code, :event_registration_id,
      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ]
    )
  end

  # Return to whichever edit page the gear was clicked from, scrolled to the row
  # (or the affiliations section after a delete removes the row).
  def affiliation_return_path(anchor: helpers.dom_id(@affiliation))
    case params[:return_to]
    when "person"
      edit_person_path(params[:origin_id], anchor: anchor, admin: params[:admin].presence)
    when "organization"
      edit_organization_path(params[:origin_id], anchor: anchor, admin: params[:admin].presence)
    else
      edit_affiliation_path(@affiliation, admin: params[:admin].presence)
    end
  end
end
