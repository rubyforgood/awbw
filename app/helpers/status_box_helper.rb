module StatusBoxHelper
  STATUS_CLASSES = {
    "info" => { surface: "bg-info-surface", border: "border-info-border", text: "text-info-fg" },
    "success" => { surface: "bg-success-surface", border: "border-success-border", text: "text-success-fg" },
    "warning" => { surface: "bg-warning-surface", border: "border-warning-border", text: "text-warning-fg" },
    "danger" => { surface: "bg-danger-surface", border: "border-danger-border", text: "text-danger-fg" },
    "neutral" => { surface: "bg-gray-50", border: "border-gray-200", text: "text-gray-800" }
  }.freeze

  FLASH_LEVELS = {
    "notice" => "info",
    "info" => "info",
    "warning" => "warning",
    "alert" => "danger",
    "error" => "danger"
  }.freeze

  def status_classes(level)
    STATUS_CLASSES.fetch(level.to_s, STATUS_CLASSES["neutral"])
  end

  def flash_status_classes(type)
    status_classes(FLASH_LEVELS.fetch(type.to_s, "neutral"))
  end
end
