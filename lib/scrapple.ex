defmodule Scrapple do
  require Logger

  defp navigate_to(%{page: page}, url) do
    Playwright.Page.goto(page, url)

    page
    |> Playwright.Page.text_content("body")
  end

  def scrape(instructions) do
    browser = Playwright.launch(:chromium)
    page = browser |> Playwright.Browser.new_page()

    data =
      instructions
      |> Enum.reduce(%{}, fn [command, value] = instructions, data ->
        ctx = %{
          page: page
        }

        case command do
          "visit" ->
            navigate_to(ctx, value)
            data

          _ ->
            data
            |> Map.merge(reduce_to_data(ctx, instructions))
        end
      end)

    {:ok, data}

    # page
    # |> Playwright.Page.goto(
    #   "https://www.searchcraigslist.net/results?#{URI.encode_query(%{q: search_query})}"
    #   |> info()
    # )

    # listings =
    #   page
    #   |> Playwright.Page.query_selector_all(".gs-webResult")

    # listings
    # |> Enum.map(fn listing_el ->
    #   listing_el
    #   |> Playwright.ElementHandle.query_selector("a.gs-title")
    #   |> Playwright.ElementHandle.get_attribute("href")
    # end)
    # |> Enum.map(fn listing_url ->
    #   :timer.sleep(trunc(:rand.uniform() * 1000))
    #   save_listing(page, listing_url)
    # end)

    # browser
    # |> Playwright.Browser.close()
  end

  defp reduce_to_data(%{page: page}, [
         "find_all",
         %{map: "get_text", name: name, selector: selector}
       ]) do
    reduced =
      page
      |> Playwright.Page.query_selector_all(selector)
      |> Enum.map(fn el -> Playwright.ElementHandle.text_content(el) |> String.trim() end)

    %{name => reduced}
  end

  defp reduce_to_data(%{page: page} = ctx, [
         "find_all",
         %{map: map_instructions, selector: selector}
       ]) do
    page
    |> Playwright.Page.query_selector_all(selector)
    |> Enum.reduce(%{}, fn el, acc ->
      reduced =
        ctx
        |> Map.put(:current_el, el)
        |> reduce_to_data(map_instructions)

      acc
      |> deep_merge(reduced)
    end)
  end

  defp reduce_to_data(%{current_el: el}, [
         "find_first",
         %{map: "get_text", name: name, selector: selector}
       ]) do
    reduced =
      Playwright.ElementHandle.query_selector(el, selector)
      |> Playwright.ElementHandle.text_content()
      |> String.trim()

    %{name => reduced}
  end

  # defp save_listing(page, listing_url) do
  #   info("Saving listing #{inspect(listing_url)}")

  #   Playwright.Page.goto(page, listing_url)

  #   page
  #   |> Playwright.Page.wait_for_selector(".posting")

  #   if listing_status(page) == :valid do
  #     title = get_text(page, "#titletextonly") |> String.trim()
  #     price = get_text(page, ".price") |> String.trim()
  #     location = get_text(page, ".area a") |> String.trim()

  #     info("Creating listing #{title}, #{price}, #{location}")

  #     {:ok, _listing} =
  #       Scrapple.Listings.create(%{title: title, price: price, location: location})
  #   end
  # end

  # defp get_text(page, css_selector), do: Playwright.Page.text_content(page, css_selector)

  # defp listing_status(page) do
  #   locator =
  #     page
  #     |> Playwright.Locator.new(".postingtitletext")

  #   if Playwright.Locator.count(locator) > 0 do
  #     :valid
  #   else
  #     page_text =
  #       page
  #       |> Playwright.Page.text_content("body")

  #     if String.contains?(page_text, "This posting has been deleted") do
  #       :deleted
  #     else
  #       :invalid
  #     end
  #   end
  # end

  def deep_merge(map1, map2) do
    resolver = fn
      _, one, two
      when not is_map(one) and not is_map(two) and not is_list(one) and not is_list(two) ->
        [one, two]

      _, _original, _override ->
        DeepMerge.continue_deep_merge()
    end

    DeepMerge.deep_merge(map1, map2, resolver)
  end

  defp info(msg) do
    Logger.info("#{inspect(__MODULE__)}: #{msg}")
    msg
  end
end
