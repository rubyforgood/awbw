class SearchController < ApplicationController
  skip_before_action :preload_current_user_associations, raise: false

  def index
    model_class = allowed_model(params[:model])
    return head :forbidden unless model_class

    authorize! model_class, to: :search?

    query = params[:q].to_s.strip
    return render json: [] if query.blank?

    records = authorized_scope(
      model_class.remote_search(query),
     **scope_options_for(model_class)
    ).limit(10)

    render json: records.map(&:remote_search_label)
  end

  private

  def allowed_model(model_param)
    {
      "person"   => Person,
      "workshop" => Workshop,
      "organization" => Organization
    }[model_param]
  end

  def scope_options_for(model_class)
    options = {}
    options[:as] = :affiliated if model_class == Organization
    # Add more options here in the future if needed
    options
  end
end
