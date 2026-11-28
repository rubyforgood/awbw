# The browser tab's <title>: what page you're on, then the app name, so a row of
# portal tabs can be told apart ("Jennifer Tilly | AWBW").
#
# A view can name its page outright with `content_for(:title, "…")`. Otherwise the
# title is read off the controller: the record it loaded (the instance variable named
# for the controller, e.g. @person on PeopleController); else the record the page
# belongs to (a ticket's registration, a nested page's event); else the controller's name.
module PageTitleHelper
  APP_TITLE = "AWBW".freeze
  SEPARATOR = " · ".freeze
  MAX_LABEL_LENGTH = 60
  LABEL_METHODS = %i[ name title display_name ].freeze
  # A nil ivar names the page by its context; the ticket's callout is the action, not the record.
  RECORD_IVARS = { "continuing_education_registrations" => :ce_registration, "events/callouts" => nil }.freeze
  CONTEXT_IVARS = %i[ event_registration event form ].freeze
  # A nil name leaves the controller out; the record and action already say it.
  RESOURCE_NAMES = {
    "events/registrations" => "ticket",
    "events/callouts" => nil,
    "events/public_registrations" => "registration",
    "public_forms" => nil,
    "faqs" => "FAQs",
    "fm_archives" => "FileMaker archives",
    "admin/ahoy_activities" => "Activity"
  }.freeze
  ACTION_NAMES = { "ce" => "CE", "ce_certificate" => "CE certificate", "faq" => "FAQ" }.freeze
  UNNAMED_ACTIONS = %w[ index show new create ].freeze

  def page_title
    specific = content_for(:title).presence || derived_page_title
    [ specific, APP_TITLE ].compact_blank.join(" | ")
  end

  private

  def derived_page_title
    if (record = page_title_own_record)
      own_record_page_title(record)
    elsif (context = CONTEXT_IVARS.lazy.filter_map { |name| page_title_ivar(name) }.first)
      [ page_title_record_label(context), page_title_resource_name, page_title_action_name ].compact_blank.join(SEPARATOR)
    else
      standalone_page_title
    end
  end

  def own_record_page_title(record)
    label = page_title_record_label(record)

    case action_name
    when "show" then label
    when "edit", "update" then "Edit #{label}"
    else [ label, page_title_action_name ].compact_blank.join(SEPARATOR)
    end
  end

  def standalone_page_title
    resource = page_title_resource_name&.upcase_first.presence || controller_name.humanize

    case action_name
    when "index", "show" then resource
    when "new", "create" then "New #{controller_name.singularize.humanize(capitalize: false)}"
    else [ resource, page_title_action_name ].join(SEPARATOR)
    end
  end

  def page_title_resource_name
    RESOURCE_NAMES.fetch(controller_path) { controller_name.humanize(capitalize: false) }
  end

  def page_title_action_name
    return if UNNAMED_ACTIONS.include?(action_name)
    return controller.instance_variable_get(:@callout)&.title if action_name == "callout"

    ACTION_NAMES.fetch(action_name) { action_name.humanize(capitalize: false) }
  end

  def page_title_own_record
    name = RECORD_IVARS.fetch(controller_path) { controller_name.singularize }
    page_title_ivar(name) if name
  end

  def page_title_ivar(name)
    record = controller.instance_variable_get("@#{name}")
    record = record.object if record.is_a?(Draper::Decorator)
    record if record.is_a?(ActiveRecord::Base) && record.persisted?
  end

  # A decorator can name its record for the tab (`page_title_label`); otherwise the
  # record's own name or title.
  def page_title_record_label(record)
    label = record.decorate.page_title_label if record.decorator_class? && record.decorator_class.method_defined?(:page_title_label)
    label = LABEL_METHODS.lazy.filter_map { |method| record.try(method).presence }.first if label.blank?
    return record.model_name.human if label.blank?

    CGI.unescapeHTML(strip_tags(label.to_s)).squish.truncate(MAX_LABEL_LENGTH)
  end
end
