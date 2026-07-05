class OtherResponsesController < ApplicationController
  before_action :set_other_response, only: :update

  # Review page: the same free-text "Other" sector value typed across many
  # people, grouped with a count so a curator can decide what to promote.
  def index
    authorize!
    responses = OtherResponse
      .sectors.where(status: OtherResponse::VISIBLE_STATUSES)
      .includes(:person)

    @groups = responses.group_by(&:normalized_text).map do |_normalized, rows|
      {
        display_text: rows.first.text,
        normalized_text: rows.first.normalized_text,
        count: rows.size,
        status_counts: rows.each_with_object(Hash.new(0)) { |r, h| h[r.status] += 1 }
      }
    end.sort_by { |group| [ -group[:count], group[:display_text].downcase ] }

    @sectors = Sector.excluding_other.order(:name)
  end

  # Curate a single response — the profile-edit "×" dismisses, and the review
  # page can keep an individual person's response.
  def update
    authorize! @other_response
    status = params.dig(:other_response, :status)
    @other_response.update!(status: status) if OtherResponse::STATUSES.include?(status)

    if params[:return_to] == "person_edit"
      redirect_to edit_person_path(@other_response.person), status: :see_other
    else
      redirect_to other_responses_path, status: :see_other
    end
  end

  # Promote every non-dismissed person who typed this value into a real Sector
  # tag — mapping to an existing sector or minting a new (published) one — and
  # mark those responses promoted so they stop showing as free-text chips.
  def promote
    authorize! to: :promote?
    sector = target_sector
    return redirect_to other_responses_path, alert: "Pick or name a sector to promote to." unless sector

    responses = OtherResponse.sectors.promotable_now
      .where(normalized_text: OtherResponse.normalize(params[:normalized_text]))

    responses.includes(:person).find_each do |response|
      response.person.tag_sectors(primary_ids: [], additional_ids: [ sector.id ])
      response.update!(status: "promoted", promotable: sector)
    end

    redirect_to other_responses_path, status: :see_other,
                notice: "Promoted #{responses.size} response(s) to “#{sector.name}”."
  end

  private

  def set_other_response
    @other_response = OtherResponse.find(params[:id])
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
