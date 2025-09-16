ActionMailer::Base.smtp_settings = {
  :address   => ENV.fetch("SMTP_SERVER", ""),
  :port      => ENV.fetch("SMTP_PORT", ""),
  :user_name => ENV.fetch("SMTP_USERNAME", ""),
  :password  => ENV.fetch("SMTP_PASSWORD", ""),
}
ActionMailer::Base.delivery_method = :smtp
