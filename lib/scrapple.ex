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

    ctx = %{
      page: page
    }

    data = reduce_instructions(ctx, instructions)

    browser
    |> Playwright.Browser.close()

    {:ok, data}
  end

  defp reduce_instructions(ctx, instructions) do
    instructions
    |> Enum.reduce(%{_ctx: ctx, _tmp: []}, fn instructions, data ->
      case instructions do
        ["visit", url] ->
          navigate_to(ctx, url)
          data

        ["map", sub_instructions] when is_list(instructions) ->
          # Figuring out a way to pass the last scraped data (extracted from the previous step, can be in ephmeral field data OR in data depending on if the user specified a name field in the last step or not)

          last_reduced_data = hd(_tmp) # ["/url1", "/url2"]
          reduce_instructions(ctx, sub_instructions)

        [_action, mapper] ->
          case reduce_to_data(ctx, instructions) do
            {:ephemeral_field, field_data} ->
              Map.put(data, :_tmp, [field_data] ++ data._tmp)

            field_data ->
              data
              |> Map.put(:_tmp, [field_data] ++ data._tmp)
              |> Map.merge(field_data)
          end
      end
    end)
    |> Map.drop([:_ctx, :_tmp])
  end

  defp reduce_to_data(%{page: page}, [
         "find_all",
         %{map: mapper, selector: selector} = instructions
       ])
       when is_binary(mapper) or is_list(mapper) do
    map_fn =
      case mapper do
        "get_text" ->
          fn el -> Playwright.ElementHandle.text_content(el) |> String.trim() end

        ["get_attribute", attr_name] ->
          fn el -> Playwright.ElementHandle.get_attribute(el, attr_name) end

        _ ->
          raise "Incorrect 'map' function while parsing selector #{selector}. Received: #{
                  inspect(mapper)
                }"
      end

    reduced =
      page
      |> Playwright.Page.query_selector_all(selector)
      |> Enum.map(map_fn)
      |> IO.inspect(label: "AFTER MAPPING #{inspect(mapper)}")

    IO.inspect(Playwright.Page.text_content(page, "body"))

    if Map.get(instructions, :name) do
      %{instructions.name => reduced}
    else
      {:ephemeral_field, reduced}
    end
  end

  defp reduce_to_data(%{page: page} = ctx, [
         "find_all",
         %{map: mapper, selector: selector}
       ])
       when is_map(mapper) do
    page
    |> Playwright.Page.query_selector_all(selector)
    |> Enum.reduce(%{}, fn el, acc ->
      reduced =
        ctx
        |> Map.put(:current_el, el)
        |> reduce_to_data(mapper)

      acc
      |> deep_merge(reduced)
    end)
  end

  defp reduce_to_data(ctx, ["find_first", mappers])
       when is_list(mappers) do
    mappers
    |> Enum.reduce(%{}, fn mapper, data ->
      Map.merge(data, reduce_to_data(ctx, ["find_first", mapper]))
    end)
  end

  defp reduce_to_data(ctx, [
         "find_first",
         %{map: "get_text", name: name, selector: selector}
       ]) do
    target =
      if el = Map.get(ctx, :current_el) do
        Playwright.ElementHandle.query_selector(el, selector)
      else
        page = Map.get(ctx, :page)

        page
        |> Playwright.Page.query_selector(selector)
      end

    data =
      target
      |> IO.inspect(label: Playwright.Page.text_content(ctx.page, "body"))
      |> Playwright.ElementHandle.text_content()
      |> String.trim()

    %{name => data}
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
