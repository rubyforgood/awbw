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
      @records = @model.order(fm_id: :desc).paginate(page: params[:page], per_page: 50)
    end
  end

  def show
    authorize! :fm_archive, to: :show?

    @selected = params[:table]
    if @selected.present? && (config = TABLES[@selected])
      @record = config[:model].find_by(fm_id: params[:id].to_s.strip)
    else
      @record = TABLES.values.map { |c| c[:model] }.filter_map { |m| m.find_by(fm_id: params[:id].to_s.strip) }.first
    end

    unless @record
      redirect_to fm_archives_path, alert: "No record found with ID '#{params[:id].to_s.strip}'"
      return
    end

    load_backlinks
  end

  private

  def load_backlinks
    @backlinks = {}
    return unless @record.class.const_defined?(:HAS_MANY)

    @record.class::HAS_MANY.each do |table, config|
      model = TABLES.values.find { |c| c[:model].table_name == table }&.dig(:model)
      next unless model
      scope = if config[:via] == :fm_id
                model.where(fm_id: @record.fm_id)
              else
                model.find_by_data(config[:via], @record.fm_id)
              end
      page_param = "#{table}_page"
      paginated = scope.order(:fm_id).paginate(page: params[page_param], per_page: 50)
      next unless paginated.any?
      @backlinks[config[:label]] = {
        table: table,
        records: paginated,
        page_param: page_param,
      }
    end
  end
end
