defmodule Scrapple do
  require Logger

  def scrape(search_query) do
    browser = Playwright.launch(:chromium)
    page = browser |> Playwright.Browser.new_page()

    page
    |> Playwright.Page.goto(
      "https://www.searchcraigslist.net/results?#{URI.encode_query(%{q: search_query})}"
      |> info()
    )

    listings =
      page
      |> Playwright.Page.query_selector_all(".gs-webResult")

    listings
    |> Enum.map(fn listing_el ->
      listing_el
      |> Playwright.ElementHandle.query_selector("a.gs-title")
      |> Playwright.ElementHandle.get_attribute("href")
    end)
    |> Enum.map(fn listing_url ->
      :timer.sleep(trunc(:rand.uniform() * 1000))
      save_listing(page, listing_url)
    end)

    browser
    |> Playwright.Browser.close()
  end

  defp save_listing(page, listing_url) do
    info("Saving listing #{inspect(listing_url)}")

    Playwright.Page.goto(page, listing_url)

    page
    |> Playwright.Page.wait_for_selector(".posting")

    if listing_status(page) == :valid do
      title = get_text(page, "#titletextonly") |> String.trim()
      price = get_text(page, ".price") |> String.trim()
      location = get_text(page, ".area a") |> String.trim()

      info("Creating listing #{title}, #{price}, #{location}")

      {:ok, _listing} =
        Scrapple.Listings.create(%{title: title, price: price, location: location})
    end
  end

  defp get_text(page, css_selector), do: Playwright.Page.text_content(page, css_selector)

  defp listing_status(page) do
    locator =
      page
      |> Playwright.Locator.new(".postingtitletext")

    if Playwright.Locator.count(locator) > 0 do
      :valid
    else
      page_text =
        page
        |> Playwright.Page.text_content("body")

      if String.contains?(page_text, "This posting has been deleted") do
        :deleted
      else
        :invalid
      end
    end
  end

  defp info(msg) do
    Logger.info("#{inspect(__MODULE__)}: #{msg}")
    msg
  end
end

defmodule Scrapple.Listings do
  alias Scrapple.Listing
  alias Scrapple.Repo

  @spec create(params :: map()) :: {:ok, %Listing{}} | {:error, Ecto.Changeset.t()}
  def create(params) do
    Listing.changeset(%Listing{}, params)
    |> Repo.insert()
  end
end
