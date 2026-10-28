module People
  class MembershipsController < ApplicationController
    before_action :set_person, only: %i[ index new create ]

    def index
      authorize! :membership

      @memberships = @person.memberships
        .includes(membership_invoices: :allocations)
        .order(created_at: :desc)
        .decorate
        .to_a
    end

    def new
      authorize! :membership

      @membership = @person.memberships.new(
        start_date: Date.current,
        end_date: Date.current + Membership::INVOICE_PERIOD - 1.day
      )
      @membership.first_invoice_cost_dollars = Membership.annual_cost_cents / 100.0
    end

    def create
      authorize! :membership

      start_date = parse_date(params.dig(:membership, :start_date)) || Date.current
      result = Membership::Create.call(
        person: @person,
        start_date: start_date,
        cost_cents: parse_cents(params.dig(:membership, :cost_dollars)),
        invoice_cost_cents: parse_cents(params.dig(:membership, :first_invoice_cost_dollars))
      )

      if result.success?
        redirect_to person_memberships_path(@person),
          notice: "Membership created with its first invoice.", status: :see_other
      else
        @membership = result.membership || @person.memberships.new(start_date: start_date)
        @membership.first_invoice_cost_dollars = params.dig(:membership, :first_invoice_cost_dollars)
        @errors = result.errors
        render :new, status: :unprocessable_content
      end
    end

    private

    def set_person
      @person = Person.find(params[:person_id])
    end

    def parse_date(value)
      return if value.blank?

      Date.parse(value)
    rescue ArgumentError, TypeError
      nil
    end

    def parse_cents(value)
      return if value.blank?

      (value.to_d * 100).to_i
    end
  end
end
