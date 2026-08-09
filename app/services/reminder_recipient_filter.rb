# Decides which event registrations on the bulk reminder page still match the
# admin's filters. The page keeps every registrant visible and only unchecks the
# ones that don't match, so this returns the set of matching ids rather than a
# narrowed list. Matching runs in memory against the already-loaded registrations
# (the action loads them all up front) so the predicates can lean on associations
# like scholarships, grants, organizations, comments and the registrant's user
# account without extra per-filter SQL.
class ReminderRecipientFilter
  # Free-text inputs matched in memory against the loaded registrations.
  TEXT_KEYS = %i[ name reg_org grantor comment email ].freeze
  # Dropdown filters shared with the registrants roster. They reuse the
  # EventRegistration scopes (run once as a query) so both pages stay in sync —
  # same param names, options, and semantics.
  DROPDOWN_KEYS = %i[
    attendance_status payment_status payment_method ce_status scholarship
    comment_status org_status account_status state county
  ].freeze
  FILTER_KEYS = (TEXT_KEYS + DROPDOWN_KEYS).freeze

  def initialize(event_registrations, params, event: nil)
    @event_registrations = event_registrations
    @params = params
    @event = event || event_registrations.first&.event
  end

  def matched_ids
    text_matched = @event_registrations.select { |reg| matches_text?(reg) }.map(&:id).to_set
    text_matched & dropdown_matched_ids
  end

  # True when at least one filter is narrowing the list. The view uses this to
  # keep "select all" checked by default and to avoid implying a filter is active
  # when none is.
  def filtering?
    FILTER_KEYS.any? { |key| @params[key].present? }
  end

  private

  def matches_text?(reg)
    matches_name?(reg) &&
      matches_reg_org?(reg) &&
      matches_grantor?(reg) &&
      matches_comment?(reg) &&
      matches_email?(reg)
  end

  # Apply the registrants-roster scopes for whichever dropdowns are set, then
  # return the matching ids. With no dropdown filter this is every registration,
  # so the text-match set passes through unchanged.
  def dropdown_matched_ids
    return @event_registrations.map(&:id).to_set if @event.nil?

    scope = @event.event_registrations
    scope = scope.attendance_status(@params[:attendance_status]) if @params[:attendance_status].present?
    scope = scope.payment_status(@params[:payment_status]) if @params[:payment_status].present?
    scope = scope.payment_method(@params[:payment_method]) if @params[:payment_method].present?
    scope = scope.ce_status(@params[:ce_status]) if @params[:ce_status].present?
    scope = scope.scholarship_status(@params[:scholarship]) if @params[:scholarship].present?
    scope = scope.comment_status(@params[:comment_status]) if @params[:comment_status].present?
    scope = scope.organization_status(@params[:org_status], @event) if @params[:org_status].present?
    scope = scope.account_status(@params[:account_status]) if @params[:account_status].present?
    scope = scope.registrant_state(@params[:state]) if @params[:state].present?
    scope = scope.registrant_county(@params[:county]) if @params[:county].present?
    scope.pluck(:id).to_set
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

  # Text filters accept several values separated by "--" and match a registrant
  # when ANY of them hits (e.g. "amy--aisha" keeps both Amy and Aisha). Single
  # hyphens inside a value are preserved. Returns true when no term was typed.
  def any_term?(key)
    tokens = @params[key].to_s.downcase.split("--").map(&:strip).reject(&:blank?)
    return true if tokens.empty?
    tokens.any? { |token| yield token }
  end
end
