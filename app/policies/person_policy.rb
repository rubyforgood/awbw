class PersonPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies

  def index?
    admin?
  end

  def show?
    admin? || owner?
  end

  # Admin, or the profile's own person. The narrow rule for owner-only content
  # (submitted ideas, workshop logs) — kept separate from `show?` so opening
  # `show?` up to public profile viewing later can't expose it.
  def own_record?
    admin? || owner?
  end

  def workshop_logs?
    admin? || owner?
  end

  def own_membership?
    owner? && Membership.enabled?
  end

  def show_email_change?
    admin? || owner?
  end

  def checkout?
    admin?
  end

  # Admin, or the profile's own person once owner self-service editing is turned
  # on (staged behind `Person.owner_editing_enabled?` for a staging trial before
  # the profile-launch flip). Owners edit their own fields and request changes to
  # the admin-only ones (primary email, affiliations); the controller strips those
  # from an owner's submission as a server-side backstop.
  def edit?
    admin? || owner_self_edit?
  end

  def update?
    admin? || owner_self_edit?
  end

  def destroy?
    admin? && record.persisted? && !has_associated_data?
  end

  def search?
    admin?
  end

  def send_form_link?
    admin?
  end

  # Scoping
  # See https://actionpolicy.evilmartians.io/#/scoping

  relation_scope do |relation|
    next relation if admin?
    relation.searchable.with_active_facilitator_affiliations.where_user_not_locked
  end

  private

  def owner?
    return false unless authenticated?
    record.user == user
  end

  def owner_self_edit?
    owner? && Person.owner_editing_enabled?
  end

  def has_associated_data?
    record.user.present? ||
      record.affiliations.exists? ||
      record.stories_as_spotlighted_facilitator.exists? ||
      record.stories_as_author.exists? ||
      record.workshop_variations_as_author.exists? ||
      record.workshops_as_author.exists? ||
      record.community_news_as_author.exists? ||
      record.resources_as_author.exists?
  end
end
