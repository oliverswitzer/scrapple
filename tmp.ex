instructions = [
  ["visit", URI.encode("https://en.wikipedia.org/wiki/Gallery_of_sovereign_state_flags")],
  [
    "find_all",
    %{
      name: "flags",
      selector: ".mw-gallery-traditional .gallerytext a:nth-child(1)",
      do: "click",
      then: [
        "find_first",
        %{
          name: "name",
          selector: ".infobox-title",
          map: "get_text"
        }
      ]
    }
  ]
]
