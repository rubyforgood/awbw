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
      @has_card = @person.stripe_customer&.payment_methods&.exists? || false
    end

    def new
      authorize! :membership

      @membership = @person.memberships.new(
        start_date: Date.current,
        end_date: Date.current + Membership::INVOICE_PERIOD - 1.day
      )
    end

    def create
      authorize! :membership

      start_date = parse_date(params.dig(:membership, :start_date)) || Date.current
      cost_cents = MoneyParser.cents(params.dig(:membership, :cost_dollars))
      invoice_cost_cents = MoneyParser.cents(params.dig(:membership, :first_invoice_cost_dollars))

      if MoneyParser.invalid?(cost_cents) || MoneyParser.invalid?(invoice_cost_cents)
        @membership = @person.memberships.new(start_date: start_date)
        @errors = [ "Enter the locked price and first invoice as numbers, e.g. 100" ]
        return render :new, status: :unprocessable_content
      end

      result = Membership::Create.call(
        person: @person,
        start_date: start_date,
        cost_cents: cost_cents,
        invoice_cost_cents: invoice_cost_cents
      )

      if result.success?
        redirect_to membership_path(result.membership),
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
  end
end
