defmodule Backendelixir.InventoryFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Backendelixir.Inventory` context.
  """

  @doc """
  Generate a item.
  """
  def item_fixture(attrs \\ %{}) do
    {:ok, item} =
      attrs
      |> Enum.into(%{
        description: "some description",
        status: "some status",
        title: "some title"
      })
      |> Backendelixir.Inventory.create_item()

    item
  end
end
