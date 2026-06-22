# Decides which event registrations on the bulk reminder page still match the
# admin's filters. The page keeps every registrant visible and only unchecks the
# ones that don't match, so this returns the set of matching ids rather than a
# narrowed list. Matching runs in memory against the already-loaded registrations
# (the action loads them all up front) so the predicates can lean on associations
# like scholarships, grants, organizations, comments and the registrant's user
# account without extra per-filter SQL.
class ReminderRecipientFilter
  FILTER_KEYS = %i[
    name reg_org grantor comment email payment_status scholarship_status
    account_status ce_status
  ].freeze

  def initialize(event_registrations, params)
    @event_registrations = event_registrations
    @params = params
  end

  def matched_ids
    @event_registrations.select { |reg| matches?(reg) }.map(&:id).to_set
  end

  # True when at least one filter is narrowing the list. The view uses this to
  # keep "select all" checked by default and to avoid implying a filter is active
  # when none is.
  def filtering?
    FILTER_KEYS.any? { |key| @params[key].present? }
  end

  private

  def matches?(reg)
    matches_name?(reg) &&
      matches_reg_org?(reg) &&
      matches_grantor?(reg) &&
      matches_comment?(reg) &&
      matches_email?(reg) &&
      matches_payment_status?(reg) &&
      matches_scholarship_status?(reg) &&
      matches_account_status?(reg) &&
      matches_ce_status?(reg)
  end

  def matches_name?(reg)
    any_term?(:name) { |term| reg.registrant.full_name.downcase.include?(term) }
  end

  def matches_reg_org?(reg)
    any_term?(:reg_org) do |term|
      reg.organizations.any? { |org| org.name.to_s.downcase.include?(term) }
    end
  end

  # Grantor = the funder behind a scholarship's grant. Only registrants who hold a
  # scholarship drawn from a grant can match, per the filter label.
  def matches_grantor?(reg)
    any_term?(:grantor) do |term|
      reg.scholarships.any? do |scholarship|
        grant = scholarship.grant
        grant.present? && grant.funder_name.to_s.downcase.include?(term)
      end
    end
  end

  def matches_comment?(reg)
    any_term?(:comment) do |term|
      reg.comments.any? { |comment| comment.body.to_s.downcase.include?(term) }
    end
  end

  # Matches against every email we hold for the registrant (their account email,
  # contact email and secondary email), so a search hits whichever address the
  # admin remembers.
  def matches_email?(reg)
    any_term?(:email) do |term|
      registrant_emails(reg).any? { |email| email.include?(term) }
    end
  end

  def registrant_emails(reg)
    person = reg.registrant
    [ person.preferred_email, person.email, person.email_2, person.user&.email ]
      .compact_blank.map(&:downcase)
  end

  def matches_payment_status?(reg)
    case @params[:payment_status].presence
    when "paid" then reg.paid_in_full?
    when "unpaid" then reg.event.cost_cents.to_i > 0 && !reg.paid_in_full?
    when "intends_to_pay" then reg.intends_to_pay?
    when "paid_or_intends" then reg.payment_access_granted?
    else true
    end
  end

  def matches_scholarship_status?(reg)
    case @params[:scholarship_status].presence
    when "requested" then reg.scholarship_requested?
    when "allocated" then reg.scholarships.any?
    when "tasks_completed"
      reg.scholarships.any? && reg.scholarships.all?(&:tasks_completed?)
    else true
    end
  end

  def matches_account_status?(reg)
    status = @params[:account_status].presence
    return true if status.blank?
    reg.account_status == status
  end

  # CE sub-statuses (missing license / missing hours) only make sense for someone
  # who actually requested CE credit, so they're gated on that. "paid" has no
  # CE-specific payment record yet, so it falls back to the registrant being paid
  # in full.
  def matches_ce_status?(reg)
    case @params[:ce_status].presence
    when "requested" then reg.ce_credit_requested?
    when "license_not_provided" then reg.ce_credit_requested? && !reg.ce_license_provided?
    when "hours_not_provided" then reg.ce_credit_requested? && reg.ce_hours_requested.to_i <= 0
    when "paid" then reg.ce_credit_requested? && reg.paid_in_full?
    else true
    end
  end

  # Text filters accept several values separated by "--" and match a registrant
  # when ANY of them hits (e.g. "amy--aisha" keeps both Amy and Aisha). Single
  # hyphens inside a value are preserved. Returns true when no term was typed.
  def any_term?(key)
    tokens = @params[key].to_s.downcase.split("--").map(&:strip).reject(&:blank?)
    return true if tokens.empty?
    tokens.any? { |token| yield token }
  end
end
