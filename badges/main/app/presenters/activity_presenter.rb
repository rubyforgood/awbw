class ActivityPresenter
  attr_reader :event, :object

  delegate :user, to: :event

  def initialize(event)
    @event  = event
    @object = load_object
  end

  # ---- What happened ----
  def action
    event.name.split(".").first
  end

  # ---- The ONE true timeline ----
  def occurred_at
    event.time
  end

  # ---- Object passthrough ----
  def decorate
    object&.decorate
  end

  def to_model
    object
  end

  def persisted? = true

  private

  def load_object
    type = event.properties["resource_type"]
    id   = event.properties["resource_id"]
    return nil unless type && id
    type.constantize.find_by(id: id)
  rescue
    nil
  end
end
