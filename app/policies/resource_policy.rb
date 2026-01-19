class ResourcePolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  alias_rule :edit?, :destroy?, to: :update?
  alias_rule :rhino_text?, to: :show?
  alias_rule :create?, :search?, to: :new?
  alias_rule :stories?, to: :index?

  def index?
    true
  end

  def download?
    true
  end

  def show?
    admin? || record.published?
  end

  def new?
    admin?
  end

  def update?
    admin? || owner?
  end

  def filter_published?
    admin?
  end

  relation_scope do |relation|
    if admin?
      relation
    else
      relation.published
    end
  end
end
