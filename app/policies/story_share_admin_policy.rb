class StoryShareAdminPolicy < ApplicationPolicy
  # Story Share portal settings are admin-only. Every action (show, reorder, add,
  # remove) falls back to ApplicationPolicy's default manage? rule (admin?).
  def show?    = admin?
  def reorder? = admin?
  def add?     = admin?
  def remove?  = admin?
end
