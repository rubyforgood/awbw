class FacilitatorDecorator < ApplicationDecorator

  def title
    "#{first_name} #{last_name}"
  end

  def detail(length: nil)
    text = user.project_users.active.map{|pu| "#{pu.title.presence || pu.position}, #{pu.project.name}"}.join(", ") if user
    length ? text&.truncate(length) : text
  end

  def inactive?
    !user ? false : user&.inactive?
  end

  def main_image
    avatar
  end

  def pronouns_display
    profile_show_pronouns ? pronouns : nil
  end

  def main_image_url
    if avatar_image&.file&.attached?
      Rails.application.routes.url_helpers.url_for(avatar_image.file)
    else
      ActionController::Base.helpers.asset_path("missing.png")
    end
  end

  def member_since_year
    member_since ? member_since.year : nil
  end

  def badges
    years = member_since ? (Time.zone.now.year - member_since.year) : 0
    badges = []
    badges << ["Legacy Facilitator (10+ years)", "yellow"] if years >= 10
    badges << ["Seasoned Facilitator (3-10 years)", DomainTheme.bg_class_for(:facilitators)] if member_since.present? && years >= 3
    badges << ["New Facilitator (<3 years)", "green"] if member_since.present? && years < 3
    badges << ["Spotlighted Facilitator", "gray"] if stories_as_spotlighted_facilitator
    badges << ["Events Attended", DomainTheme.bg_class_for(:events)] if user.events.any?
    badges << ["Workshop Author", DomainTheme.bg_class_for(:workshops)] if user.workshops.any? # indigo
    badges << ["Story Author", DomainTheme.bg_class_for(:stories)] if user.stories_as_creator.any? # pink
    badges << ["Sector Leader", DomainTheme.bg_class_for(:sectors)] if sectorable_items.where(is_leader: true).any?
    badges << ["Blog Contributor", "orange"] if true # || user.respond_to?(:blogs) && user.blogs.any? # red
    badges
  end
end
