defmodule Scrapple do
  require Logger

  def scrape(instructions) do
    browser = Playwright.launch(:chromium)
    page = browser |> Playwright.Browser.new_page()

    ctx = %{
      page: page
    }

    data =
      instructions
      |> Enum.reduce(ctx, fn [command, value] = instructions, data ->
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
  end

  defp navigate_to(%{page: page}, url) do
    Playwright.Page.goto(page, url)

    page
    |> Playwright.Page.text_content("body")
  end

  # Find all + Take an action on each one
  defp reduce_to_data(
         %{page: page} = ctx,
         ["find_all", %{do: action, then: next_instructions, name: name, selector: selector}]
       ) do
    case action do
      "click" ->
        locator = Playwright.Locator.new(page, selector)

        reductions =
          0..(Playwright.Locator.count(locator) - 1)
          |> Enum.reduce([], fn i, acc ->
            Playwright.Locator.nth(locator, i)
            |> Playwright.Locator.click()

            data = reduce_to_data(ctx, next_instructions)

            Playwright.Page.evaluate(page, "history.back()")

            [data] ++ acc
          end)

        %{name => Enum.reverse(reductions)}

      _ ->
        nil
    end
  end

  # Find all + Extract data from each element 
  defp reduce_to_data(%{page: page} = ctx, [
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
          # Further reduce for each element
          fn el ->
            ctx
            |> Map.put(:current_el, el)
            |> reduce_to_data(mapper)
          end
      end

    reduced =
      if el = Map.get(ctx, :current_el) do
        Playwright.ElementHandle.query_selector_all(el, selector)
        |> Enum.map(map_fn)
      else
        page
        |> Playwright.Page.query_selector_all(selector)
        |> Enum.map(map_fn)
      end

    if Map.get(instructions, :name) do
      %{instructions.name => reduced}
    else
      reduced
      |> Enum.reduce(%{}, fn r, acc ->
        deep_merge(acc, r)
      end)
    end
  end

  defp reduce_to_data(ctx, ["find_first", mappers])
       when is_list(mappers) do
    mappers
    |> Enum.reduce(%{}, fn mapper, data ->
      Map.merge(data, reduce_to_data(ctx, ["find_first", mapper]))
    end)
  end

  defp reduce_to_data(ctx, ["find_first", %{map: mapper, selector: selector} = instructions]) do
    data =
      case mapper do
        "get_text" ->
          get_text(ctx, selector)

        ["get_attribute", attr_name] ->
          get_attribute(ctx, selector, attr_name)

        _ ->
          # Further reduce for each element
          el = Playwright.Page.query_selector(ctx.page, selector)

          ctx
          |> Map.put(:current_el, el)
          |> reduce_to_data(mapper)
      end

    if name = Map.get(instructions, :name) do
      %{name => data}
    else
      data
    end
  end

  defp reduce_to_data(ctx, [
         "find_first",
         %{map: "get_text", name: name, selector: selector}
       ]) do
    data =
      if el = Map.get(ctx, :current_el) do
        target = Playwright.ElementHandle.query_selector(el, selector)

        if target do
          target
          |> Playwright.ElementHandle.text_content()
          |> String.trim()
        else
          raise "Couldn't find element within parent el #{inspect(el)} with selector: #{selector}"
        end
      else
        page = Map.get(ctx, :page)

        target =
          page
          |> Playwright.Page.query_selector(selector, %{timeout: 1_000})

        if target do
          target
          |> Playwright.ElementHandle.text_content()
          |> String.trim()
        else
          raise "Couldn't find element with selector #{selector} on page: #{Playwright.Page.text_content(page, "document")}"
        end
      end

    %{name => data}
  end

  # Clearly duplicated and needs to be DRYed up (see `get_text/2` below)
  def get_attribute(ctx, selector, attr_name) do
    if el = Map.get(ctx, :current_el) do
      target = Playwright.ElementHandle.query_selector(el, selector)

      if target do
        target
        |> Playwright.ElementHandle.get_attribute(attr_name)
        |> String.trim()
      else
        raise "Couldn't find element within parent el #{inspect(el)} with selector: #{selector}"
      end
    else
      page = Map.get(ctx, :page)

      target =
        page
        |> Playwright.Page.query_selector(selector, %{timeout: 1_000})

      if target do
        target
        |> Playwright.ElementHandle.get_attribute(attr_name)
        |> String.trim()
      else
        raise "Couldn't find element with selector #{selector} on page: #{Playwright.Page.text_content(page, "document")}"
      end
    end
  end

  def get_text(ctx, selector) do
    if el = Map.get(ctx, :current_el) do
      target = Playwright.ElementHandle.query_selector(el, selector)

      if target do
        target
        |> Playwright.ElementHandle.text_content()
        |> String.trim()
      else
        raise "Couldn't find element within parent el #{inspect(el)} with selector: #{selector}"
      end
    else
      page = Map.get(ctx, :page)

      target =
        page
        |> Playwright.Page.query_selector(selector, %{timeout: 1_000})

      if target do
        target
        |> Playwright.ElementHandle.text_content()
        |> String.trim()
      else
        raise "Couldn't find element with selector #{selector} on page: #{Playwright.Page.text_content(page, "document")}"
      end
    end
  end

  @dialyzer {:nowarn_function, {:deep_merge, 2}}
  # See https://github.com/PragTob/deep_merge/issues/12

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

  # defp info(msg) do
  #   Logger.info("#{inspect(__MODULE__)}: #{msg}")
  #   msg
  # end
end
