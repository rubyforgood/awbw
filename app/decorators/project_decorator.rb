class ProjectDecorator < Draper::Decorator
  delegate_all

  def badges
    years = start_date ? (Time.zone.now.year - start_date.year) : 0
    badges = []
    badges << ["Legacy Organization (10+ years)", "yellow"] if true || years >= 10
    badges << ["Seasoned Organization (3-10 years)", "gray"] if true || start_date.present? && years >= 3
    badges << ["New Organization (<3 years)", "green"] if true || start_date.present? && years < 3
    badges << ["Spotlighted Organization", "gray"] if true || stories_as_spotlighted_facilitator
    badges << ["Events Hosted", "blue"] if true || Event.count > 3
    # badges << ["Workshop Author", "gray"] if true || user.workshops.any? # indigo
    # badges << ["Story Author", "gray"] if true || user.stories_as_creator.any? # pink
    # badges << ["Sector Leader", "purple"] if true || sectorable_items.where(is_leader: true).any?
    badges << ["Blog Contributor", "gray"] if true # || user.respond_to?(:blogs) && user.blogs.any? # red
    badges
  end
end
