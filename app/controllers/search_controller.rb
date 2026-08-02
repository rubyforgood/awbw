class SearchController < ApplicationController
  skip_before_action :preload_current_user_associations, raise: false

  # Virtual "model" that searches people and organizations together for the
  # compound payer / donor pickers. The optional `order` param picks which kind
  # is listed first ("organization" → organizations first; anything else →
  # people first) — both search the same two tables.
  COMPOUND_MODEL = "person_or_organization".freeze

  def index
    return render json: compound_results if params[:model] == COMPOUND_MODEL

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

  # Search people and organizations, concatenating in the order the caller
  # asked for so each picker can lead with its most common kind.
  def compound_results
    model_classes = params[:order] == "organization" ? [ Organization, Person ] : [ Person, Organization ]
    model_classes.each { |klass| authorize! klass, to: :search? }

    query = params[:q].to_s.strip
    return [] if query.blank?

    model_classes
      .flat_map { |klass| authorized_scope(klass.remote_search(query)).limit(25).to_a }
      .map(&:compound_search_label)
  end

  def allowed_model(model_param)
    {
      "person"   => Person,
      "user"     => User,
      "workshop" => Workshop,
      "organization" => Organization,
      "event" => Event,
      "event_registration" => EventRegistration,
      "resource" => Resource
    }[model_param]
  end

  def scope_options_for(model_class)
    options = {}
    # options[:as] = :affiliated if model_class == Organization
    # Add more options here in the future if needed
    options
  end
end
