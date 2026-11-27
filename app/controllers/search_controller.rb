class SearchController < ApplicationController
  skip_before_action :preload_current_user_associations, raise: false

  # Virtual "model" that searches people and organizations together for the
  # compound payer / funder pickers, listing organizations first.
  COMPOUND_MODEL = "person_or_organization".freeze
  # Every login, whatever its access, labelled with why it can't sign in — for the users deduper
  # and the import user setting.
  USER_ANY_STATUS_MODEL = "user_any_status".freeze
  # Suffix on a search model for the dedupe pickers, which also match a portal id or FileMaker code.
  DEDUPE_SUFFIX = "_dedupe".freeze

  def index
    return render json: compound_results if params[:model] == COMPOUND_MODEL
    return render json: user_any_status_results if params[:model] == USER_ANY_STATUS_MODEL
    return dedupe_results(params[:model].delete_suffix(DEDUPE_SUFFIX)) if params[:model].to_s.end_with?(DEDUPE_SUFFIX)

    model_class = allowed_model(params[:model])
    unless model_class
      skip_verify_authorized!
      return head :forbidden
    end

    authorize! model_class, to: :search?

    query = params[:q].to_s.strip
    return render json: [] if query.blank?

    records = authorized_scope(
      model_class.remote_search(query),
     **scope_options_for(model_class)
    )

    if params[:exclude].present?
      exclude_ids = params[:exclude].split(",").map(&:to_i)
      records = records.where.not(id: exclude_ids)
    end

    records = records.limit(25)

    labels = records.map(&:remote_search_label)
    labels = model_class.resolve_duplicate_labels(labels) if model_class.respond_to?(:resolve_duplicate_labels)

    render json: labels
  end

  private

  # Search people and organizations, listing organizations first (the more
  # common funder/payer).
  def compound_results
    authorize! Organization, to: :search?
    authorize! Person, to: :search?

    query = params[:q].to_s.strip
    return [] if query.blank?

    records = authorized_scope(Organization.remote_search(query)).limit(25).to_a +
      authorized_scope(Person.remote_search(query)).limit(25).to_a

    records.map(&:compound_search_label)
  end

  def user_any_status_results
    authorize! User, to: :search?

    query = params[:q].to_s.strip
    return [] if query.blank?

    records = authorized_scope(User.activity_search(query))
    records = records.where.not(id: params[:exclude].split(",").map(&:to_i)) if params[:exclude].present?
    records.includes(:person).limit(25).map { |user| user.decorate.search_label_with_status }
  end

  # The picker's usual text matches, then any record the query names by exact portal id or
  # whole FileMaker code. Labels end with the portal id so same-named records tell apart.
  def dedupe_results(search_model)
    any_status_user = search_model == USER_ANY_STATUS_MODEL
    model_class = any_status_user ? User : allowed_model(search_model)
    unless model_class
      skip_verify_authorized!
      return head :forbidden
    end
    authorize! model_class, to: :dedupe?

    query = params[:q].to_s.strip
    return render json: [] if query.blank?

    text_matches = any_status_user ? User.activity_search(query).includes(:person) : model_class.remote_search(query)
    identifier_matches = model_class.matching_identifier(query).limit(25).to_a
    records = (text_matches.limit(25 - identifier_matches.size).to_a + identifier_matches).uniq
    render json: records.map { |record|
      row = any_status_user ? record.decorate.search_label_with_status : record.remote_search_label
      row[:label].include?("##{record.id}") ? row : row.merge(label: "#{row[:label]} · ##{record.id}")
    }
  end

  def allowed_model(model_param)
    {
      "person"   => Person,
      "user"     => User,
      "workshop" => Workshop,
      "story" => Story,
      "organization" => Organization,
      "event" => Event,
      "event_registration" => EventRegistration,
      "resource" => Resource,
      "sector" => Sector,
      "category" => Category
    }[model_param]
  end

  def scope_options_for(model_class)
    options = {}
    # options[:as] = :affiliated if model_class == Organization
    # Add more options here in the future if needed
    options
  end
end
