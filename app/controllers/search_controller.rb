class SearchController < ApplicationController
  skip_before_action :preload_current_user_associations, raise: false

  # Virtual "models" that search people and organizations together. Both search
  # the same two tables; they differ only in result order. The payer /
  # additional-designation pickers on the payment form list people first; the
  # grant donor picker lists organizations first (organizations are the more
  # common donor).
  COMPOUND_MODELS = {
    "person_or_organization" => [ Person, Organization ],
    "organization_or_person" => [ Organization, Person ]
  }.freeze

  def index
    compound_classes = COMPOUND_MODELS[params[:model]]
    return render json: compound_results(compound_classes) if compound_classes

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

  # Search each model in turn and concatenate, preserving the given class order
  # so the caller controls which kind is listed first.
  def compound_results(model_classes)
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
