defmodule Test.ScrappleTest do
  use ScrappleWeb.ConnCase

  test "just visiting a website works", %{test: test_name, conn: conn} do
    page_fixture =
      html_tree("""
      <div>Some page</div>
      """)

    upload_fixture(conn, test_name, page_fixture)

    instructions = [
      ["visit", "http://localhost:4002/#{test_name}"]
    ]

    assert {:ok, _} = Scrapple.scrape(instructions)
  end

  test "getting data off of one page", %{test: test_name, conn: conn} do
    page_fixture =
      html_tree("""
        <div class="first_page_list_item">
          First item
        </div>
        <div class="first_page_list_item">
          Second item
        </div>
      """)

    upload_fixture(conn, test_name, page_fixture)

    instructions = [
      ["visit", "http://localhost:4002/#{test_name}"],
      [
        "find_all",
        %{
          name: "first_page_list_items",
          selector: ".first_page_list_item",
          map: "get_text"
        }
      ]
    ]

    assert {:ok, result} = Scrapple.scrape(instructions)

    assert %{
             "first_page_list_items" => ["First item", "Second item"]
           } = result
  end

  test "getting multiple nested pieces of data off of one page find_all and then find_first in each one)",
       %{test: test_name, conn: conn} do
    page_fixture =
      html_tree("""
        <div class="top_level_thing">
          <div class="nested_thing">Nested thing 1</div>
        </div>
        <div class="top_level_thing">
          <div class="nested_thing">Nested thing 2</div>
        </div>
      """)

    upload_fixture(conn, test_name, page_fixture)

    instructions = [
      ["visit", "http://localhost:4002/#{test_name}"],
      [
        "find_all",
        %{
          # Omitting name means that this first level of nesting is ignored in the returned data response
          selector: ".top_level_thing",
          map: [
            "find_first",
            %{selector: ".nested_thing", name: "nested_things", map: "get_text"}
          ]
        }
      ]
    ]

    assert {:ok, result} = Scrapple.scrape(instructions)

    assert %{
             "nested_things" => ["Nested thing 1", "Nested thing 2"]
           } = result
  end

  test "find_first to target parent el and then a find_all within that el", %{
    test: test_name,
    conn: conn
  } do
    page_fixture =
      html_tree("""
        <div class="some_top_level_thing_that_doesnt_matter">
          <div class="nested_thing">Nested thing 1</div>
          <div class="nested_thing">Nested thing 2</div>
        </div>
        <div class="top_level_thing">
          <div class="nested_thing">Nested thing 3</div>
          <div class="nested_thing">Nested thing 4</div>
        </div>
      """)

    upload_fixture(conn, test_name, page_fixture)

    instructions = [
      ["visit", "http://localhost:4002/#{test_name}"],
      [
        "find_first",
        %{
          selector: ".top_level_thing",
          map: [
            "find_all",
            %{selector: ".nested_thing", name: "nested_things", map: "get_text"}
          ]
        }
      ]
    ]

    assert {:ok, result} = Scrapple.scrape(instructions)

    assert %{
             "nested_things" => ["Nested thing 3", "Nested thing 4"]
           } = result
  end

  @tag :skip
  test "nested targeting with find_first and then find_all", %{
    test: test_name,
    conn: conn
  } do
    IO.puts(
      "This test is currently failing because Playwright.ElementHandle.query_selector_all() just returns all elements on the page and not just elements within the element passed in as first argument."
    )

    page_fixture =
      html_tree("""
        <! –– the .nested_thing elements and h1 below should never be returned since
        we are only targeting .nested_thing's and h1's inside of .top_level_thing ––>

        <h1>im not nested at all</h1>
        <div class="top_level_thing_2">
          <div class="nested_thing">Nested thing 1</div>
          <div class="nested_thing">Nested thing 2</div>
        </div>

        <div class="top_level_thing">
          <h1>im the first nested thing</h1>
          <div class="top_level_thing_2">
            <div class="nested_thing">Nested thing 3</div>
            <div class="nested_thing">Nested thing 4</div>
          </div>
        </div>
      """)

    upload_fixture(conn, test_name, page_fixture)

    instructions = [
      ["visit", "http://localhost:4002/#{test_name}"],
      [
        "find_first",
        %{
          selector: ".top_level_thing",
          map: [
            "find_first",
            [
              %{selector: "h1", name: "header", map: "get_text"},
              %{
                selector: ".top_level_thing_2",
                map: [
                  "find_all",
                  %{name: "super_nested_thing", selector: ".nested_thing", map: "get_text"}
                ]
              }
            ]
          ]
        }
      ]
    ]

    assert {:ok, result} = Scrapple.scrape(instructions)

    assert %{
             "header" => "im the first nested thing",
             "super_nested_thing" => ["Nested thing 3", "Nested thing 4"]
           } = result
  end

  test "getting data off of multiple pages", %{test: test_name, conn: conn} do
    first_page_fixture =
      html_tree("""
        <div class="first_page_list_item">
          <a href="/#{test_name}-second_page/1">First link</a>
        </div>
        <div class="first_page_list_item">
          <a href="/#{test_name}-second_page/2">Second link</a>
        </div>
      """)

    second_page_fixture =
      html_tree("""
        <h1 id="second_page_header">second page :id</h1>
        <a id="third_page_link" href="/#{test_name}-third_page/:id">link to third page :id</a>
      """)

    third_page_fixture =
      html_tree("""
        <h1 id="third_page_header">third page :id</h1>
      """)

    upload_fixture(conn, "#{test_name}-first_page", first_page_fixture)
    upload_fixture(conn, "#{test_name}-second_page", second_page_fixture)
    upload_fixture(conn, "#{test_name}-third_page", third_page_fixture)

    instructions = [
      ["visit", URI.encode("http://localhost:4002/#{test_name}-first_page")],
      [
        "find_all",
        %{
          name: "first_page_list_items",
          selector: ".first_page_list_item a",
          do: "click",
          then: [
            "find_first",
            [
              %{
                name: "second_page_header",
                selector: "#second_page_header",
                map: "get_text"
              },
              %{
                selector: "a#third_page_link",
                do: "click",
                then: [
                  "find_first",
                  %{
                    name: "third_page_header",
                    selector: "#third_page_header",
                    map: "get_text"
                  }
                ]
              }
            ]
          ]
        }
      ]
    ]

    {:ok, result} = Scrapple.scrape(instructions)

    assert %{
             "first_page_list_items" => [
               %{
                 "second_page_header" => "second page 1",
                 "third_page_header" => "third page 1"
               },
               %{
                 "second_page_header" => "second page 2",
                 "third_page_header" => "third page 2"
               }
             ]
           } = result
  end

  defp html_tree(html) do
    """
    <!DOCTYPE html>
    <html>
     <head>
       <meta charset="UTF-8" />
       <meta name="viewport" content="width=device-width" />
       <title>Scrapple Fixture</title>
     </head>
     <body>
       #{html} 
     </body>
    </html>
    """
  end

  defp upload_fixture(conn, name, content) do
    conn
    |> put_req_header("content-type", "application/json")
    |> post("/test/upload_fixture/#{name}", Jason.encode!(%{fixture: content}))
  end
end
