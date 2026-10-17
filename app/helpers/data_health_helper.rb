module DataHealthHelper
  # Back to Data health, reopening the check the admin came from when it's known.
  def data_health_return_path(check = params[:check])
    key = DataHealth.find(check)&.key
    key ? admin_data_health_path(open: key, anchor: "check-#{key}") : admin_data_health_path
  end
end
