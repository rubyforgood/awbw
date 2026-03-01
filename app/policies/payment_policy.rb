class PaymentPolicy < ApplicationPolicy
  relation_scope do |relation|
    next relation if admin?

    relation.none
  end
end
