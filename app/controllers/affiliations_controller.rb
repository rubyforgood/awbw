class AffiliationsController < ApplicationController
  include AhoyTracking

  DEDUPE_PURPOSE = "affiliation_dedupe".freeze

  SORTS = {
    "organization" => "organizations.name %{dir}, people.last_name %{dir}, people.first_name %{dir}",
    "person" => "people.last_name %{dir}, people.first_name %{dir}",
    "title" => "affiliations.title %{dir}",
    "start_date" => "affiliations.start_date %{dir}",
    "end_date" => "affiliations.end_date %{dir}",
    "primary_contact" => "affiliations.primary_contact %{dir}",
    "inactive" => "affiliations.inactive %{dir}",
    "address" => "affiliations.organization_address_id %{dir}",
    "filemaker_code" => "affiliations.filemaker_code %{dir}",
    "event" => "event_registrations.event_id %{dir}",
    "comments" => "(SELECT COUNT(*) FROM comments WHERE comments.commentable_type = 'Affiliation' " \
                  "AND comments.commentable_id = affiliations.id) %{dir}",
    "id" => "affiliations.id %{dir}"
  }.freeze

  before_action :set_affiliation, only: %i[ edit update save_inline save_note destroy ]
  before_action :set_registration_choices, only: %i[ edit update ]

  def index
    authorize!
    return render :index unless turbo_frame_request?

    @sort = SORTS.key?(params[:sort]) ? params[:sort] : "organization"
    @sort_direction = params[:direction] == "desc" ? "desc" : "asc"
    order = format(SORTS[@sort], dir: @sort_direction)
    @affiliations = Affiliation.search_by_params(params)
      .left_joins(:person, :organization, :event_registration)
      .includes(:person, :organization_address, :comments, organization: :addresses, event_registration: :event)
      .reorder(Arel.sql("#{order}, affiliations.id ASC"))
      .paginate(page: params[:page], per_page: params[:number_of_items_per_page].presence || 50)
    @registration_choices = registration_choices_for(@affiliations)
    render :affiliations_results
  end

  def edit
    authorize! @affiliation
  end

  def dedupe_index
    authorize! Affiliation, to: :dedupe?
    @groups = AffiliationServices::DuplicateFinder.new(dedupe_scope).groups
  end

  def dedupe_perform
    authorize! Affiliation, to: :dedupe?
    person = GlobalID::Locator.locate_signed(params[:person_sgid], for: DEDUPE_PURPOSE, only: Person)
    raise ActiveRecord::RecordNotFound, "Person not found" unless person

    merged = merge_affiliations(person)
    track_event("dedupe.affiliation", { resource_type: "Person", resource_id: person.id, affiliations_merged: merged })
    redirect_to dedupe_index_affiliations_path(query: params[:query].presence), notice: "Merged #{helpers.pluralize(merged, "duplicate affiliation")}."
  rescue ActionPolicy::Unauthorized
    raise
  rescue StandardError => e
    redirect_to dedupe_index_affiliations_path(query: params[:query].presence), alert: "Error merging affiliations: #{e.message}"
  end

  def update
    authorize! @affiliation
    # This form always posts the Inactive checkbox, so whatever it sends is deliberate.
    @affiliation.inactive_supplied = affiliation_params.key?(:inactive)
    @affiliation.assign_attributes(affiliation_params)

    if @affiliation.save
      redirect_to affiliation_return_path, notice: "Affiliation was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  # The index's inline autosave: one start date, end date, inactive flag, primary contact, address, FileMaker code, or linked registration at a time.
  def save_inline
    authorize! @affiliation, to: :update?
    attrs = params.require(:affiliation).permit(:start_date, :end_date, :inactive, :primary_contact, :organization_address_id, :filemaker_code, :event_registration_id)
    @affiliation.inactive_supplied = attrs.key?(:inactive)
    @affiliation.assign_attributes(attrs)
    return render json: { error: save_error }, status: :unprocessable_content unless @affiliation.save

    @choices = registration_choices_for([ @affiliation ]).fetch(@affiliation.id)

    respond_to do |format|
      format.turbo_stream
      format.any { head :ok }
    end
  end

  # The index's inline comment: edits the newest comment, or adds one when there's none.
  def save_note
    authorize! @affiliation, to: :update?
    @affiliation.save_index_note(params[:note])
    respond_to do |format|
      format.turbo_stream
      format.any { head :ok }
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

  # Narrows to the people the search names, keeping each person's whole duplicate sets.
  def dedupe_scope
    query = params[:query].to_s.strip
    return Affiliation.all if query.blank?

    Affiliation.where(person_id: Affiliation.matching_text_or_identifier(:matching_name, query).select(:person_id))
  end

  def merge_affiliations(person)
    ActiveRecord::Base.transaction do
      before = person.affiliations.count
      AffiliationDeduper.new(person).call
      before - person.affiliations.count
    end
  end

  # Each affiliation's pickable registrations, newest event first: its person's own,
  # plus the one it's linked to now (which may be someone else's).
  def registration_choices_for(affiliations)
    affiliations = affiliations.to_a
    registrations = EventRegistration.where(registrant_id: affiliations.map(&:person_id))
      .or(EventRegistration.where(id: affiliations.filter_map(&:event_registration_id)))
      .includes(:event).to_a
    by_person = registrations.group_by(&:registrant_id)
    by_id = registrations.index_by(&:id)

    affiliations.to_h do |affiliation|
      choices = by_person.fetch(affiliation.person_id, []) | [ by_id[affiliation.event_registration_id] ].compact
      [ affiliation.id, choices.sort_by { |registration| -registration.event&.start_date.to_i } ]
    end
  end

  # skip_if_duplicate aborts the save without adding an error.
  def save_error
    @affiliation.errors.full_messages.to_sentence.presence || "matches another affiliation"
  end

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
      :person_id, :organization_id, :type, :title, :start_date, :end_date, :inactive, :primary_contact,
      :organization_address_id, :filemaker_code, :event_registration_id,
      comments_attributes: [ :id, :topic, :body, :flagged, :_destroy ],
      notifications_attributes: Notification::PERMITTED_LOG_ATTRIBUTES
    )
  end

  # Return to whichever page the editor was opened from; a person or organization page is
  # scrolled to the row (or the affiliations section after a delete removes the row).
  def affiliation_return_path(anchor: @affiliation.decorate.return_anchor)
    case params[:return_to]
    when "person"
      edit_person_path(params[:origin_id], anchor: anchor, admin: params[:admin].presence)
    when "organization"
      edit_organization_path(params[:origin_id], anchor: anchor, admin: params[:admin].presence)
    when "fm_archive"
      fm_archive_path(params[:origin_id], table: params[:origin_table].presence)
    else
      edit_affiliation_path(@affiliation, admin: params[:admin].presence)
    end
  end
end
