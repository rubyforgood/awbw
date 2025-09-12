class Api::V1::AuthenticationsController < Api::V1::ApiController
  skip_before_action :authenticate_api_user!
  api :POST, '/v1/authentications'
  param :email, String, 'User\'s email', required: true
  param :password, String, 'User\'s password', required: true
  desc 'With valid credentials, return\'s an API Authorization token'
  def create
    user = User.find_by_email(params[:email])
    if user.present? && user.valid_password?(params[:password])

      sign_in user
      token = AuthenticationToken.generate_token(user.id).to_s
      render json: { token: token, user: user, url: "#{request.base_url}/?Authorization=#{token}" }, status: :created
    else
      render json: { error: 'Not Authorized', status: :unauthorized }
    end
  end
end
