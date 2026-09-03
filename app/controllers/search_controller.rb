class SearchController < ApplicationController
  skip_before_action :preload_current_user_associations, raise: false

  # Virtual "model" that searches people and organizations together for the
  # compound payer / funder pickers, listing organizations first.
  COMPOUND_MODEL = "person_or_organization".freeze

  # Virtual "model" backing the global comments index's "New comment" picker —
  # every type Comment#commentable can polymorphically point at (mirrors the
  # case in CommentsHelper#commentable_label), searched together in one box.
  COMMENTABLE_MODEL = "commentable".freeze
  COMMENTABLE_MODELS = [
    Person, User, EventRegistration, Scholarship, ContinuingEducationRegistration,
    TopicSubscription, Story, StoryIdea, Affiliation, StaffTagging
  ].freeze

  def index
    return render json: compound_results if params[:model] == COMPOUND_MODEL
    return render json: commentable_results if params[:model] == COMMENTABLE_MODEL

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

  # Search across every commentable type at once, so the "Add a note to…" picker
  # on the global comments index doesn't force a type pick first.
  def commentable_results
    COMMENTABLE_MODELS.each { |model_class| authorize! model_class, to: :search? }

    query = params[:q].to_s.strip
    return [] if query.blank?

    records = COMMENTABLE_MODELS.flat_map { |model_class| authorized_scope(model_class.remote_search(query)).limit(10).to_a }

    records.map(&:compound_search_label)
  end

  def allowed_model(model_param)
    {
      "person"   => Person,
      "user"     => User,
      "workshop" => Workshop,
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
