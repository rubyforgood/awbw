class SearchController < ApplicationController
  def index
    model_class = allowed_model(params[:model])
    return head :forbidden unless model_class

    authorize! model_class, to: :search?

    query = params[:q].to_s.strip
    return render json: [] if query.blank?

    records = model_class
      .remote_search(query)
      .limit(10)

    render json: records.map(&:remote_search_label)
  end

  private

  def allowed_model(model_param)
    {
      "person"   => Person,
      "workshop" => Workshop
    }[model_param]
  end
end
