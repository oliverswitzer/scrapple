defmodule Scrapple.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      Scrapple.Repo,
      # Start the Telemetry supervisor
      ScrappleWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Scrapple.PubSub},
      # Start the Endpoint (http/https)
      ScrappleWeb.Endpoint,
      {Test.FixturesCatalog, name: Test.FixturesCatalog}
      # Start a worker by calling: Scrapple.Worker.start_link(arg)
      # {Scrapple.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Scrapple.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ScrappleWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
