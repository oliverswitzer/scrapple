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
  end

  test "getting data off of multiple pages", %{test: test_name, conn: conn} do
    first_page_fixture =
      html_tree("""
        <div class="first_page_list_item">
          <a href="/second_page/1"></a> 
        </div>
        <div class="first_page_list_item">
          <a href="/second_page/2"></a> 
        </div>
      """)

    second_page_fixture =
      html_tree("""
        <h1 id="second_page_header">header :id</h1>
        <h1 id="second_page_other_thing">other thing :id</h1>
      """)

    upload_fixture(conn, "#{test_name}-first_page", first_page_fixture)
    upload_fixture(conn, "#{test_name}-second_page", second_page_fixture)

    instructions = [
      ["visit", "http://localhost:4002/first_page"],
      [
        "find_all",
        %{
          name: "first_page_list_items",
          selector: ".first_page_list_item a",
          do: "follow_link",
          then: [
            "find_first",
            [
              %{
                name: "second_page_header",
                selector: "#second_page_header",
                map: "get_text"
              },
              %{
                name: "second_page_other_thing",
                selector: "#second_page_other_thing",
                map: "get_text"
              }
            ]
          ]
        }
      ]
    ]

    {:ok, result} = Scrapple.scrape(instructions)

    assert %{
             first_page_list_items: [
               %{
                 second_page_header: "header 1",
                 second_page_other_thing: "other thing 1"
               },
               %{
                 second_page_header: "header 2",
                 second_page_other_thing: "other thing 2"
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
