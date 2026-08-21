module StatusBoxHelper
  STATUS_CLASSES = {
    "info" => { surface: "bg-blue-50", border: "border-blue-300", text: "text-blue-800" },
    "success" => { surface: "bg-green-50", border: "border-green-300", text: "text-green-800" },
    "warning" => { surface: "bg-yellow-50", border: "border-yellow-300", text: "text-yellow-800" },
    "danger" => { surface: "bg-red-50", border: "border-red-300", text: "text-red-800" },
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
