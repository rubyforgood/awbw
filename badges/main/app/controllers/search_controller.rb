class SearchController < ApplicationController
  skip_before_action :preload_current_user_associations, raise: false

  # Virtual "model" that searches people and organizations together for the
  # compound payer / funder pickers, listing organizations first.
  COMPOUND_MODEL = "person_or_organization".freeze
  # Every login, whatever its access, labelled with why it can't sign in — for the users deduper.
  USER_ANY_STATUS_MODEL = "user_any_status".freeze

  def index
    return render json: compound_results if params[:model] == COMPOUND_MODEL
    return render json: user_any_status_results if params[:model] == USER_ANY_STATUS_MODEL

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
