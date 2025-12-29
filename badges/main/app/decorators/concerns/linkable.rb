# app/decorators/concerns/linkable.rb
module Linkable
  extend ActiveSupport::Concern

  def link_target
    external_link? ? normalized_url(external_url) : super
  end

  def external_link?
    external_url.present? && valid_external_url?(external_url)
  end

  def external_url
    raise NotImplementedError, "#{self.class.name} must define #external_url"
  end

  private

  def default_link_target
    Rails.application.routes.url_helpers.polymorphic_path(self)
  end

  def valid_external_url?(value)
    return false if value.blank?

    if value =~ /\A[\w.-]+\.[a-z]{2,}/i
      value = "https://#{value}" unless value =~ /\Ahttps?:\/\//i
    end

    uri = URI.parse(value)
    uri.host.present? && %w[http https].include?(uri.scheme&.downcase)
  rescue URI::InvalidURIError
    false
  end

  def normalized_url(value)
    return "" if value.blank?
    value =~ /\Ahttp(s)?:\/\// ? value : "https://#{value}"
  end
end
