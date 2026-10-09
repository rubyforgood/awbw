module CollapsibleSectionHelpers
  # Form sections render as collapsed <details> (Affiliations, Addresses,
  # Comments & communications, …), and Capybara treats everything but the
  # <summary> as invisible while they're closed. Open one by its element id so
  # the specs below can reach its fields.
  #
  # Sets `open` by id rather than clicking the summary: clicking meant handing
  # Selenium a node reference, which Chrome ties to the document that was live at
  # the time and reports as "Node with given id does not belong to the document"
  # once a later Turbo render replaces it. The real click is covered by
  # spec/system/collapsed_section_deep_link_spec.rb.
  def expand_section(id)
    expect(page).to have_css("##{id}", visible: :all)

    page.execute_script(<<~JS, id)
      const section = document.getElementById(arguments[0]);
      if (section) section.open = true;
    JS

    expect(page).to have_css("##{id}[open]", visible: :all)
  end
end
