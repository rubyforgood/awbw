# Reads invoice page-view Ahoy events for a record, counting only recipient
# opens (the viewer_role stamped when the event is tracked), so an admin
# previewing an invoice never registers as the recipient having seen it. Hosts
# define INVOICE_VIEW_EVENT with their Ahoy event name.
module InvoiceViewTrackable
  extend ActiveSupport::Concern

  RECIPIENT_VIEWS = "JSON_UNQUOTE(JSON_EXTRACT(ahoy_events.properties, '$.viewer_role')) = 'recipient'".freeze

  class_methods do
    def recipient_invoice_views
      Ahoy::Event.where(name: self::INVOICE_VIEW_EVENT, resource_type: name).where(RECIPIENT_VIEWS)
    end

    def invoice_viewed
      where(id: recipient_invoice_views.select(:resource_id))
    end

    def invoice_not_viewed
      where.not(id: recipient_invoice_views.select(:resource_id))
    end
  end

  def invoice_views
    self.class.recipient_invoice_views.where(resource_id: id).order(:time)
  end

  def invoice_view_times
    invoice_views.pluck(:time)
  end

  def invoice_viewed?
    invoice_views.exists?
  end
end
