module ChipHelper
  # Palette for the small person chips shown on comments and communications — a
  # stable color per person id so the same staff member always reads the same
  # across both.
  CHIP_COLORS = [
    [ "bg-sky-100", "text-sky-800" ],
    [ "bg-purple-100", "text-purple-800" ],
    [ "bg-pink-100", "text-pink-800" ],
    [ "bg-indigo-100", "text-indigo-800" ],
    [ "bg-orange-100", "text-orange-800" ],
    [ "bg-yellow-200", "text-yellow-800" ],
    [ "bg-blue-100", "text-blue-800" ],
    [ "bg-green-100", "text-green-800" ]
  ].freeze

  def chip_color(id)
    CHIP_COLORS[(id || 0) % CHIP_COLORS.length]
  end
end
