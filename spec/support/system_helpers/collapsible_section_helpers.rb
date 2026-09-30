module CollapsibleSectionHelpers
  # Form sections render as collapsed <details> (Affiliations, Addresses, Sectors,
  # …), and Capybara treats everything but the <summary> as invisible while
  # they're closed. Open one by its element id so the specs below can reach its
  # fields. Idempotent — a section the form already rendered open is left alone.
  # Read `open` as a DOM property: Selenium reports the boolean attribute as the
  # string "false" when the section is closed, which is truthy in Ruby.
  def expand_section(id)
    section = find("##{id}", visible: :all)
    return if page.evaluate_script("arguments[0].open", section.native)

    section.find(:xpath, "./summary").click
  end
end
