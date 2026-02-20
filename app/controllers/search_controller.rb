class SearchController < ApplicationController
  def index
    model_class = allowed_model(params[:model])
    return head :forbidden unless model_class

    authorize! model_class, to: :search?

    query = params[:q].to_s.strip
    return render json: [] if query.blank?

    records = model_class
      .where(search_condition(model_class), *search_params(model_class, query))
      .limit(10)

    render json: records.map { |r| serialize(r) }
  end

  private

  def allowed_model(model_param)
    {
      "person"  => Person
    }[model_param]
  end

  def search_condition(model_class)
    case model_class.name
    when "Person"
      "LOWER(first_name) LIKE ? OR LOWER(last_name) LIKE ?"
    end
  end

  def search_params(model_class, query)
    pattern = "%#{query.downcase}%"
    case model_class.name
    when "Person"
      [ pattern, pattern ]  # must match 2 placeholders
    else
      [ pattern ]
    end
  end

  def serialize(record)
    case record
    when Person
      {
        id: record.id,
        label: record.preferred_email.present? ? "#{record.full_name} (#{record.preferred_email})" : record.full_name
      }
    end
  end
end
