defmodule Scrapple.Repo.Migrations.CreateListings do
  use Ecto.Migration

  def change do
    create table(:listings) do
      add :title, :string
      add :price, :string
      add :location, :string
      add :listing_id, :string

      timestamps()
    end
  end
end
