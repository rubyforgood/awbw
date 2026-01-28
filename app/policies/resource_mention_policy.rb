# frozen_string_literal: true

class ResourceMentionPolicy < ApplicationPolicy
  # Scope resources based on admin status
  scope_for :relation do |relation|
    if admin?
      relation.all
    else
      relation.where(kind: Resource::PUBLISHED_KINDS)
    end
  end
end
