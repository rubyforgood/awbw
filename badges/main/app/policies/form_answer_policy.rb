class FormAnswerPolicy < ApplicationPolicy
  relation_scope do |relation|
    next relation if admin?
    relation.none
  end

  def index?
    admin?
  end
end
