class FmArchivesController < ApplicationController
  TABLES = {
    "rolodexes" => { model: FmRolodex, label: "Rolodex" },
    "organizations" => { model: FmOrganization, label: "Organizations" },
    "projects" => { model: FmProject, label: "Projects" },
    "events" => { model: FmEvent, label: "Events" },
    "services" => { model: FmService, label: "Service" },
    "personnels" => { model: FmPersonnel, label: "Personnel" },
    "payments" => { model: FmPayment, label: "Payments" },
    "participants" => { model: FmParticipant, label: "Participants" },
    "activities" => { model: FmActivity, label: "Activity" },
    "notes" => { model: FmNote, label: "Notes" },
    "addresses" => { model: FmAddress, label: "Addresses" },
    "phone_numbers" => { model: FmPhoneNumber, label: "Phone Numbers" },
    "workshop_logs" => { model: FmWorkshopLog, label: "Workshop Logs" },
    "expenditures" => { model: FmExpenditure, label: "Expenditure" },
    "funding" => { model: FmFunding, label: "Funding" },
    "allocations" => { model: FmAllocation, label: "Allocations" },
    "program_sponsorships" => { model: FmProgramSponsorship, label: "Program Sponsorships" },
    "postal_codes" => { model: FmPostalCode, label: "Postal Codes" },
  }

  def index
    authorize! :fm_archive, to: :index?

    @tables = TABLES
    @selected = params[:table]

    if @selected && (config = TABLES[@selected])
      @model = config[:model]
      @records = @model.order(:fm_id).paginate(page: params[:page], per_page: 50)
    end
  end

  def show
    authorize! :fm_archive, to: :show?

    @record = TABLES.values.map { |c| c[:model] }.filter_map { |m| m.find_by(fm_id: params[:id]) }.first
    raise ActiveRecord::RecordNotFound, "No FM record with fm_id=#{params[:id]}" unless @record
  end
end
