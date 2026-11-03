class MembershipDirectory
  PAYMENT_FILTERS = %w[ any overdue paid ].freeze

  LARGE_SET_THRESHOLD = 200

  def initialize(params)
    @params = params
  end

  def status
    @status ||= @params[:status].presence_in(Membership::DIRECTORY_STATUSES) || "all"
  end

  def payment
    @payment ||= @params[:payment].presence_in(PAYMENT_FILTERS) || "any"
  end

  def person_name
    @person_name ||= @params[:person_name].presence
  end

  def organization_ids
    @organization_ids ||= Array(@params[:organization_ids])
      .filter_map { |id| id.presence&.to_i }
      .uniq
  end

  def scope
    @scope ||= begin
      relation = Membership.all
      relation = relation.public_send(status) unless status == "all"
      relation = relation.by_person_name(person_name) if person_name.present?
      if organization_ids.any?
        relation = relation.where(person_id: Person.organization_ids(organization_ids).select(:id))
      end
      apply_payment(relation)
    end
  end

  def count = scope.count

  def large? = count > LARGE_SET_THRESHOLD

  def email_addresses
    Person.where(id: scope.select(:person_id))
      .includes(:user)
      .filter_map { |person| person.preferred_email.presence }
      .uniq
      .sort
  end

  def filter_params
    {
      status: status,
      payment: payment,
      person_name: person_name.presence,
      organization_ids: organization_ids.presence
    }.compact
  end

  private

  def apply_payment(relation)
    overdue_ids = MembershipInvoice.overdue.select(:membership_id)

    case payment
    when "overdue" then relation.where(id: overdue_ids)
    when "paid" then relation.where.not(id: overdue_ids).where(start_date: ..Date.current)
    else relation
    end
  end
end
