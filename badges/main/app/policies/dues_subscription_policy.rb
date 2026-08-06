class DuesSubscriptionPolicy < ApplicationPolicy
  def manage? = admin? && Dues.enabled?

  params_filter do |params|
    next params.permit(:cost_dollars, :cancelled) if admin?

    params.permit(:cancelled)
  end
end
