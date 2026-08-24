# Shared styling for the comment + communication rows — the combined section on
# a record's edit page and the standalone All comments & communications page use
# the same chips and card tints, so both live here rather than in one view.
module ChipHelper
  # Stable color per author id, shared by the comment and communication chips.
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

  # Border + background for a comment card. `warning` is the amber tint for an
  # imported [AGE_RANGE_DATA] note. Staff-only-ness is signalled by the add
  # button alone — tinting every card blue read as a wall of blue.
  def comment_card_class(warning: false)
    return "border-amber-200 bg-amber-50" if warning

    "#{DomainTheme.border_class_for(:comments, intensity: 200)} #{DomainTheme.bg_class_for(:comments, intensity: 50)}"
  end

  def communication_card_class
    "#{DomainTheme.border_class_for(:notifications, intensity: 200)} #{DomainTheme.bg_class_for(:notifications, intensity: 50)}"
  end
end
