defmodule Scrapple.Listing do
  use Ecto.Schema
  import Ecto.Changeset

  schema "listings" do
    field(:listing_id, :string)
    field(:location, :string)
    field(:price, :string)
    field(:title, :string)

    timestamps()
  end

  @doc false
  def changeset(listing, attrs) do
    listing
    |> cast(attrs, [:title, :price, :location, :listing_id])
    |> put_hashed_listing_id()
    |> validate_required([:title, :price, :location, :listing_id])
  end

  def put_hashed_listing_id(changeset) do
    %{title: title, location: location} =
      changeset.data
      |> Map.merge(changeset.changes)

    hashed_listing_id =
      :crypto.hash(:sha, "#{title}:#{location}")
      |> Base.encode16()

    put_change(changeset, :listing_id, hashed_listing_id)
  end
end
