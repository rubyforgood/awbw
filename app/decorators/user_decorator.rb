class UserDecorator < Draper::Decorator
  delegate_all
  def full_name
    return unless user
    if first_name.empty?
      email
    else
      "#{first_name} #{last_name}"
    end
  end

  def last_logged_in
    return 'never' unless last_sign_in_at
    "#{h.time_ago_in_words(last_sign_in_at)} ago"
  end

  def display_primary_address
    primary_address == 1 ? 'work' : 'home'
  end
end
