defmodule ScrappleWeb.TestFixturesController do
  use ScrappleWeb, :controller

  alias Test.FixturesCatalog

  def upload(conn, params) do
    fixture_name = params["fixture_name"]
    fixture_content = params["fixture"]

    :ok = FixturesCatalog.add_fixture(Test.FixturesCatalog, fixture_name, fixture_content)

    conn
    |> put_status(:created)
    |> json(%{data: []})
  end

  def show(conn, params) do
    fixture_details = params["fixture_details"]
    fixture_name = List.first(fixture_details)

    fixture_resource_id =
      if(length(fixture_details) > 1, do: List.last(fixture_details), else: nil)

    case FixturesCatalog.get_fixture(Test.FixturesCatalog, fixture_name, fixture_resource_id) do
      {:ok, fixture_content} ->
        render(conn, "show.html", content: fixture_content)

      :no_fixture ->
        render(conn, "error.html")
    end
  end
end

defmodule ScrappleWeb.TestFixturesView do
  use ScrappleWeb, :view

  def render("show.html", assigns) do
    ~H"""
      <%= raw(@content) %>
    """
  end

  def render("error.html", assigns) do
    ~H"""
    <p>No template found</p>
    """
  end
end

defmodule Test.FixturesCatalog do
  use GenServer

  def start_link(default) when is_list(default) do
    GenServer.start_link(__MODULE__, default, name: __MODULE__)
  end

  @impl true
  def init(_args) do
    {:ok, %{fixtures: %{}}}
  end

  @spec add_fixture(pid() | term(), String.t(), String.t()) :: :ok
  def add_fixture(pid, name, content) do
    GenServer.cast(pid, {:add_fixture, name, content})
  end

  @spec get_fixture(pid() | term(), String.t(), String.t() | nil) ::
          {:ok, String.t()} | :no_fixture
  def get_fixture(pid, name, id \\ nil) do
    case GenServer.call(pid, {:get_fixture, name, id}) do
      nil -> :no_fixture
      fixture -> {:ok, fixture}
    end
  end

  # Callbacks

  @impl true
  def handle_call({:get_fixture, name, id}, _from, state) do
    state.fixtures
    |> Map.get(name)
    |> interpolate(id)
    |> reply(state)
  end

  defp interpolate(fixture_content, id) do
    if id && fixture_content do
      String.replace(fixture_content, ":id", id, global: true)
    else
      fixture_content
    end
  end

  @impl true
  def handle_cast({:add_fixture, name, content}, state) do
    state
    |> Map.put(:fixtures, Map.merge(state.fixtures, %{name => content}))
    |> noreply()
  end

  def reply(res, state) do
    {:reply, res, state}
  end

  defp noreply(state), do: {:noreply, state}
end
