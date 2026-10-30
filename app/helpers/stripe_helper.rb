module StripeHelper
  def stripe_payment_intent_url(id)
    stripe_dashboard_url(id)
  end

  def stripe_charge_url(id)
    stripe_dashboard_url(id)
  end

  private

  def stripe_dashboard_url(id)
    return if id.blank?

    mode = Stripe.api_key.to_s.start_with?("sk_live") ? "" : "test/"
    "https://dashboard.stripe.com/#{mode}payments/#{ERB::Util.url_encode(id)}"
  end
end
