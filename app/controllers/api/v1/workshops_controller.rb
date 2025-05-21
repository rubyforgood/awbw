class Api::V1::WorkshopsController < Api::V1::ApiController
  api :GET, '/v1/workshops'
  param :Authorization, String, desc: 'API Authorization token returned by successful'\
                                      ' user authentication', required: true
  param :sector, String, desc: "One of #{Sector.all.pluck(:name).join(', ')}"
  desc 'Without a Sector parameter, gives a list of workshops grouped by '\
       'Sector, including quotes and images.  Relates to the "Related Workshops" '\
       'view in Sector Impacts'
  def index
    sector = Sector.find_by_name(params[:sector]) || Sector.all

    workshops = sector.to_json(only: :name, :include => {
      :workshops => { only: [:id, :title, :description],
        :include => [
          { :windows_type => { only: :name } },
          { :quotes => { only: :quote } },
          { :sectors => { only: :name } }
        ],
        :methods => [:main_image_url, :sector_hashtags]
      }
    })

    render json: workshops, status: :ok
  end
end
