defmodule Scrapple.Repo do
  use Ecto.Repo,
    otp_app: :scrapple,
    adapter: Ecto.Adapters.Postgres
end
