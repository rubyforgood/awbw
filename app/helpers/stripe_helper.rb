module StripeHelper
  def stripe_payment_url(id)
    stripe_dashboard_url("payments", id)
  end

  def stripe_customer_url(id)
    stripe_dashboard_url("customers", id)
  end

  private

  def stripe_dashboard_url(section, id)
    return if id.blank?

    mode = Stripe.api_key.to_s.start_with?("sk_live", "rk_live") ? "" : "test/"
    "https://dashboard.stripe.com/#{mode}#{section}/#{ERB::Util.url_encode(id)}"
  end
end
