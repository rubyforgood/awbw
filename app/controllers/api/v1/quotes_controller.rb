class Api::V1::QuotesController < Api::V1::ApiController
  api :GET, '/v1/quotes'
  param :Authorization, String, desc: 'API Authorization token returned by successful'\
                                      ' user authentication', required: true
  param :sector, String, desc: "One of #{Sector.all.pluck(:name).join(', ')}"
  desc 'Without a Sector parameter, gives a list of all quotes grouped by Sector.'
  def index
    sector = Sector.find_by(name: params[:sector]) || Sector.all
    quotes = sector.to_json(only: :name, :include => {
      :quotes => { only: :quote }
    })
    render json: { quotes: quotes }, status: :ok
  end
end
