# frozen_string_literal: true

class MonthlyReportsController < ApplicationController
  def index
    authorize! MonthlyReport
    @organization = Organization.find_by(id: params[:organization_id])

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      base_scope = authorized_scope(MonthlyReport.includes(:created_by, :windows_type, :organization))
      filtered = base_scope.search(params)
      @monthly_reports_unpaginated = filtered
      @monthly_reports = filtered.paginate(page: params[:page], per_page: per_page)
      @count_display = filtered.count == base_scope.count ? base_scope.count : "#{filtered.count}/#{base_scope.count}"
      compute_participant_totals(filtered, @monthly_reports)

      render :monthly_reports_results
    else
      base_scope = authorized_scope(MonthlyReport.all)
      @monthly_reports_unpaginated = base_scope.search(params)
      @count_display = @monthly_reports_unpaginated.count
      set_index_variables
      render :index
    end
  end

  def show
    @monthly_report = MonthlyReport.includes(
      :organization, :windows_type, { created_by: :person },
      { quotes: :workshop },
      { gallery_assets: { file_attachment: :blob } }
    ).find(params[:id]).decorate
    authorize! @monthly_report
    @answers    = @monthly_report.report_form_field_answers.includes(:form_field)
    @updated_by = Ahoy::Event.where(resource_type: "MonthlyReport", resource_id: @monthly_report.id)
                              .where("name LIKE 'update.%'")
                              .order(time: :desc)
                              .first&.user
  end

  private

  # Aggregates "Total # On-going Participants" and "Total # First-Time Participants"
  # answers across MRs by joining report_form_field_answers → form_fields. Values
  # are stored as text on the answers table, so we CAST to UNSIGNED (MySQL — non-
  # numeric strings cast to 0). Sets @grand_totals (across the unpaginated filtered
  # set) and @participant_lookup (per-row lookup for the current page).
  def compute_participant_totals(filtered_scope, page_scope)
    ongoing_field_ids    = MonthlyReport.participant_field_ids(MonthlyReport::PARTICIPANT_ONGOING_QUESTION)
    first_time_field_ids = MonthlyReport.participant_field_ids(MonthlyReport::PARTICIPANT_FIRST_TIME_QUESTION)

    sum_for = ->(field_ids, report_ids) {
      return 0 if field_ids.empty?
      ReportFormFieldAnswer.where(form_field_id: field_ids, report_id: report_ids)
        .sum(Arel.sql("CAST(report_form_field_answers.answer AS UNSIGNED)")).to_i
    }

    filtered_ids = filtered_scope.select(:id)
    @grand_totals = {
      ongoing:    sum_for.call(ongoing_field_ids,    filtered_ids),
      first_time: sum_for.call(first_time_field_ids, filtered_ids)
    }

    page_ids = page_scope.map(&:id)
    @participant_lookup = Hash.new { |h, k| h[k] = { ongoing: 0, first_time: 0 } }
    return if page_ids.empty?

    ReportFormFieldAnswer
      .where(form_field_id: ongoing_field_ids + first_time_field_ids, report_id: page_ids)
      .pluck(:report_id, :form_field_id, :answer)
      .each do |report_id, field_id, answer|
        key = ongoing_field_ids.include?(field_id) ? :ongoing : :first_time
        @participant_lookup[report_id][key] = answer.to_i
      end
  end

  def set_index_variables
    cache_key_prefix = "monthly_reports/index_dropdowns/#{current_user&.id}"
    @month_year_options = Rails.cache.fetch("#{cache_key_prefix}/month_year", expires_in: 5.minutes) do
      scoped = authorized_scope(MonthlyReport.all)
      scoped.group("DATE_FORMAT(COALESCE(reports.date, reports.created_at, NOW()), '%Y-%m')")
            .select("DATE_FORMAT(COALESCE(reports.date, reports.created_at, NOW()), '%Y-%m') AS ym,
                     MAX(COALESCE(reports.date, reports.created_at)) AS max_dt")
            .order("max_dt DESC")
            .map { |record| [ Date.strptime(record.ym, "%Y-%m").strftime("%B %Y"), record.ym ] }
    end
    @year_options = Rails.cache.fetch("#{cache_key_prefix}/year", expires_in: 5.minutes) do
      scoped = authorized_scope(MonthlyReport.all)
      scoped.pluck(Arel.sql("DISTINCT EXTRACT(YEAR FROM COALESCE(reports.date, reports.created_at, NOW()))")).sort.reverse
    end

    scoped_users = authorized_scope(User.all, as: :colleagues)
    @users = scoped_users.or(User.where(id: @monthly_reports_unpaginated.select(:created_by_id)))
                         .joins(:person)
                         .distinct
                         .select("users.id, users.email, users.person_id, people.first_name, people.last_name")
                         .order(Arel.sql("LOWER(people.first_name), LOWER(people.last_name), LOWER(users.email), LOWER(people.email_2), LOWER(people.email)"))
    @organizations = authorized_scope(Organization.all, as: :affiliated).order(:name)
    @workshops = Workshop.where(id: @monthly_reports_unpaginated.select(:workshop_id).distinct)
                         .includes(:windows_type)
                         .order(:title)
  end
end
