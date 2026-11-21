class CommentPolicy < ApplicationPolicy
  alias_rule :index?, :create?, :update?, :destroy?, to: :manage?

  def manage?
    admin?
  end

  relation_scope do |relation|
    next relation if admin?
    relation.none
  end
end
