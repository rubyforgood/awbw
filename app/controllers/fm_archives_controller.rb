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
    "phone_numbers" => { model: FmPhoneNumber, label: "Phone numbers" },
    "workshop_logs" => { model: FmWorkshopLog, label: "Workshop logs" },
    "expenditures" => { model: FmExpenditure, label: "Expenditure" },
    "fundings" => { model: FmFunding, label: "Funding" },
    "allocations" => { model: FmAllocation, label: "Allocations" },
    "program_sponsorships" => { model: FmProgramSponsorship, label: "Program sponsorships" },
    "postal_codes" => { model: FmPostalCode, label: "Postal codes" },
    "ancillary_data" => { model: FmAncillaryData, label: "Ancillary data" },
    "art_purchases" => { model: FmArtPurchase, label: "Art purchases" },
    "art_registries" => { model: FmArtRegistry, label: "Art registries" },
    "campaigns" => { model: FmCampaign, label: "Campaigns" },
    "committee_meetings" => { model: FmCommitteeMeeting, label: "Committee meetings" },
    "committee_members" => { model: FmCommitteeMember, label: "Committee members" },
    "committees" => { model: FmCommittee, label: "Committees" },
    "contacts" => { model: FmContact, label: "Contacts" },
    "donor_developers" => { model: FmDonorDeveloper, label: "Donor developers" },
    "email_addresses" => { model: FmEmailAddress, label: "Email addresses" },
    "exhibited_items" => { model: FmExhibitedItem, label: "Exhibited items" },
    "form_fields" => { model: FmFormField, label: "Form fields" },
    "form_letters" => { model: FmFormLetter, label: "Form letters" },
    "forms_lists" => { model: FmFormsList, label: "Forms list" },
    "form_submissions" => { model: FmFormSubmission, label: "Form submissions" },
    "group_members" => { model: FmGroupMember, label: "Group members" },
    "groups" => { model: FmGroup, label: "Groups" },
    "invoices" => { model: FmInvoice, label: "Invoices" },
    "line_items" => { model: FmLineItem, label: "Line items" },
    "match_donations" => { model: FmMatchDonation, label: "Match donations" },
    "people_to_organizations" => { model: FmPeopleToOrganization, label: "People to organizations" },
    "quotations" => { model: FmQuotation, label: "Quotations" },
    "reportings" => { model: FmReporting, label: "Reporting" },
    "solicitations" => { model: FmSolicitation, label: "Solicitations" },
    "volunteers" => { model: FmVolunteer, label: "Volunteers" },
    "workshops" => { model: FmWorkshop, label: "Workshops" }
  }

  TABLE_GROUPS = [
    { label: "People", icon: "👥", tables: %w[rolodexes activities ancillary_data contacts group_members groups] },
    { label: "Organizations & programs", icon: "🏫", tables: %w[organizations people_to_organizations projects personnels services] },
    { label: "Contact details", icon: "📇", tables: %w[addresses email_addresses phone_numbers postal_codes] },
    { label: "Events", icon: "📆", tables: %w[events exhibited_items participants payments volunteers] },
    { label: "Invoicing", icon: "🧾", tables: %w[invoices line_items] },
    { label: "Workshops", icon: "🎨", tables: %w[workshops workshop_logs] },
    { label: "Art & quotes", icon: "🖼️", tables: %w[art_registries art_purchases quotations] },
    { label: "Fundraising", icon: "🤝", tables: %w[campaigns donor_developers match_donations solicitations] },
    { label: "Grants & funding", icon: "💰", tables: %w[funding allocations expenditures program_sponsorships reporting] },
    { label: "Forms & letters", icon: "📋", tables: %w[forms_lists form_fields form_letters form_submissions] },
    { label: "Committees", icon: "🏛️", tables: %w[committees committee_meetings committee_members] },
    { label: "Other", icon: "📎", tables: %w[notes] }
  ]

  def index
    authorize! :fm_archive

    @tables = TABLES
    @table_groups = TABLE_GROUPS
    @selected = params[:table]

    if @selected && (config = TABLES[@selected])
      @model = config[:model]
      @records = @model.order(fm_id: :desc).paginate(page: params[:page], per_page: 50)
    end
  end

  def show
    authorize! :fm_archive

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
        page_param: page_param
      }
    end
  end
end
