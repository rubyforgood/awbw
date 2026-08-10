class CategoryPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # override or add new rules here that are not defined in ApplicationPolicy

  def index?   = admin?
  def show?    = admin?
  def create?  = admin?
  def update?  = admin?
  def destroy? = record.persisted? && admin?
  def search?  = admin?

  def tags_index?
    true
  end

  relation_scope do |relation|
    next relation if admin?
    relation.none
  end

  relation_scope(:taggable) do |relation|
    next relation.has_taggings if admin?
    relation.published.has_published_taggings
  end
end
