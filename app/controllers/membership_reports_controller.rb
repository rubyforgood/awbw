class MembershipReportsController < ApplicationController
  def index
    authorize! :membership
    @report = MembershipReport.new(year: params[:year])
    @year_options = @report.year_options
    @summary = @report.summary
    @view = MembershipReport.view(params[:view])
    load_results
  end

  private

  def load_results
    case @view
    when "collected" then @invoices = load_page(@report.collected_invoices)
    when "outstanding" then @invoices = load_page(@report.outstanding_invoices)
    when "closed_out" then @memberships = load_page(@report.closed_out_memberships)
    when "still_owing" then @memberships = load_page(@report.still_owing_memberships)
    when "ended" then @memberships = load_page(@report.all_ended_memberships)
    end
  end

  def load_page(scope)
    page = scope.paginate(page: params[:page], per_page: 25)
    page.total_entries
    page.load
  end
end
