class OtherResponsesController < ApplicationController
  before_action :set_other_response, only: :update

  # Review page: the same free-text "Other" value typed across many people,
  # grouped so a curator can decide what to do. Sector "Other"s are bucketed
  # together (they all promote into the one Sector catalog); every other question
  # is grouped on its own, since its "Other"s are unrelated auxiliary data.
  def index
    authorize!
    @status_filter = params[:status].presence_in(OtherResponse::REVIEWABLE_STATUSES)
    statuses = @status_filter ? [ @status_filter ] : OtherResponse::REVIEWABLE_STATUSES
    responses = OtherResponse.where(status: statuses).includes(:owner, :source_form_answer)

    @groups = responses
      .group_by { |response| [ response.group_key, response.normalized_text ] }
      .map { |_key, rows| build_group(rows) }
      .sort_by { |group| [ group[:promotable] ? 0 : 1, group[:question_label].downcase, -group[:count], group[:display_text].downcase ] }

    @sectors = Sector.excluding_other.order(:name)
  end

  # Bulk keep/dismiss every visible person in a group, from the review queue.
  # Keep leaves the value in place; dismiss hides it.
  def curate
    authorize!
    status = params[:status]
    unless %w[kept dismissed].include?(status)
      return redirect_to other_responses_path, alert: "Choose keep or dismiss."
    end

    # Act on every still-reviewable row so "Keep all" can also revive a dismissed
    # value; already-promoted rows are left alone.
    scope = group_scope.promotable_now
    count = scope.count
    scope.find_each { |response| response.update!(status: status) }

    verb = status == "kept" ? "Kept" : "Dismissed"
    redirect_to other_responses_path(status: params[:return_status].presence),
                status: :see_other, notice: "#{verb} #{count} response(s)."
  end

  # Curate a single response — the profile-edit "×" dismisses, and the review
  # page can keep an individual person's response.
  def update
    authorize! @other_response
    status = params.dig(:other_response, :status)
    @other_response.update!(status: status) if OtherResponse::STATUSES.include?(status)

    if params[:return_to] == "person_edit"
      redirect_to edit_person_path(@other_response.owner), status: :see_other
    else
      redirect_to other_responses_path, status: :see_other
    end
  end

  # Promote every non-dismissed person in a sector group into a real Sector tag —
  # mapping to an existing sector or minting a new (published) one — and mark
  # those responses promoted so they stop showing as free-text chips. Only sector
  # groups are promotable, enforced by the .sectors scope.
  def promote
    authorize!
    sector = target_sector
    return redirect_to other_responses_path, alert: "Pick or name a sector to promote to." unless sector

    responses = group_scope.sectors.promotable_now
    responses.includes(:owner).find_each do |response|
      # Reuse registration's tagging so the sector lands on the person AND the
      # org(s) they registered with, always as an additional tag (never primary).
      SectorTagging.apply(person: response.owner, organizations: response.registration_organizations,
                          additional_ids: [ sector.id ])
      response.update!(status: "promoted", promotable: sector)
    end

    redirect_to other_responses_path, status: :see_other,
                notice: "Promoted #{responses.size} response(s) to “#{sector.name}”."
  end

  private

  def set_other_response
    @other_response = OtherResponse.find(params[:id])
  end

  def build_group(rows)
    first = rows.first
    {
      kind: first.kind,
      field_identifier: first.field_identifier,
      promotable: first.promotable?,
      question_label: question_label_for(first),
      display_text: first.text,
      normalized_text: first.normalized_text,
      anchor: first.review_anchor,
      count: rows.size,
      status_counts: rows.each_with_object(Hash.new(0)) { |r, h| h[r.status] += 1 }
    }
  end

  def question_label_for(response)
    case response.kind
    when "sector" then "Sectors"
    when "organization_type" then "Organization type"
    else response.source_form_answer&.question_name_when_answered.presence || response.field_identifier.humanize
    end
  end

  # The set of responses a curate/promote action targets, matching how the group
  # was bucketed: captured kinds by kind, generic questions by field.
  def group_scope
    scope = OtherResponse.where(normalized_text: OtherResponse.normalize(params[:normalized_text]))
    if params[:kind].present? && params[:kind] != "generic"
      scope.where(kind: params[:kind])
    else
      scope.where(field_identifier: params[:field_identifier])
    end
  end

  # The promote target: an existing sector by id, or a newly minted published one
  # from a typed name. Returns nil when neither was supplied.
  def target_sector
    if params[:sector_id].present?
      Sector.find_by(id: params[:sector_id])
    elsif params[:new_sector_name].present?
      Sector.find_or_create_by!(name: params[:new_sector_name].strip) do |sector|
        sector.published = true
      end
    end
  end
end
