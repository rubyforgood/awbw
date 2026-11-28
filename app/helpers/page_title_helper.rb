# The browser tab's <title>: what page you're on, then the app name, so a row of
# portal tabs can be told apart ("Jennifer Tilly | AWBW").
#
# A view can name its page outright with `content_for(:title, "…")`. Otherwise the
# title is read off the controller: the record it loaded (the instance variable named
# for the controller, e.g. @person on PeopleController) on member pages, the
# controller's name on index pages.
module PageTitleHelper
  APP_TITLE = "AWBW".freeze
  SEPARATOR = " · ".freeze
  MAX_LABEL_LENGTH = 60
  LABEL_METHODS = %i[ name title display_name ].freeze

  def page_title
    specific = content_for(:title).presence || derived_page_title
    [ specific, APP_TITLE ].compact_blank.join(" | ")
  end

  private

  def derived_page_title
    record = page_title_record
    resource = controller_name.humanize

    case action_name
    when "index" then resource
    when "new", "create" then "New #{controller_name.singularize.humanize(capitalize: false)}"
    else
      return [ resource, action_name.humanize(capitalize: false) ].join(SEPARATOR) unless record

      label = page_title_record_label(record)
      label = "Edit #{label}" if %w[ edit update ].include?(action_name)
      label = [ label, action_name.humanize(capitalize: false) ].join(SEPARATOR) unless %w[ show edit update ].include?(action_name)
      label
    end
  end

  def page_title_record
    record = controller.instance_variable_get("@#{controller_name.singularize}")
    record = record.object if record.is_a?(Draper::Decorator)
    record if record.is_a?(ActiveRecord::Base) && record.persisted?
  end

  # A decorator can name its record for the tab (`page_title_label`); otherwise the
  # record's own name or title.
  def page_title_record_label(record)
    decorated_label = record.decorate.page_title_label if record.decorator_class? && record.decorator_class.method_defined?(:page_title_label)
    return decorated_label if decorated_label.present?

    name = LABEL_METHODS.lazy.filter_map { |method| record.try(method).presence }.first
    return record.model_name.human if name.blank?

    strip_tags(name.to_s).squish.truncate(MAX_LABEL_LENGTH)
  end
end
