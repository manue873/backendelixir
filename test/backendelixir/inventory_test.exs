defmodule Backendelixir.InventoryTest do
  use Backendelixir.DataCase

  alias Backendelixir.Inventory

  describe "items" do
    alias Backendelixir.Inventory.Item

    import Backendelixir.InventoryFixtures

    @invalid_attrs %{status: nil, description: nil, title: nil}

    test "list_items/0 returns all items" do
      item = item_fixture()
      assert Inventory.list_items() == [item]
    end

    test "get_item!/1 returns the item with given id" do
      item = item_fixture()
      assert Inventory.get_item!(item.id) == item
    end

    test "create_item/1 with valid data creates a item" do
      valid_attrs = %{status: "some status", description: "some description", title: "some title"}

      assert {:ok, %Item{} = item} = Inventory.create_item(valid_attrs)
      assert item.status == "some status"
      assert item.description == "some description"
      assert item.title == "some title"
    end

    test "create_item/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Inventory.create_item(@invalid_attrs)
    end

    test "update_item/2 with valid data updates the item" do
      item = item_fixture()

      update_attrs = %{
        status: "some updated status",
        description: "some updated description",
        title: "some updated title"
      }

      assert {:ok, %Item{} = item} = Inventory.update_item(item, update_attrs)
      assert item.status == "some updated status"
      assert item.description == "some updated description"
      assert item.title == "some updated title"
    end

    test "update_item/2 with invalid data returns error changeset" do
      item = item_fixture()
      assert {:error, %Ecto.Changeset{}} = Inventory.update_item(item, @invalid_attrs)
      assert item == Inventory.get_item!(item.id)
    end

    test "delete_item/1 deletes the item" do
      item = item_fixture()
      assert {:ok, %Item{}} = Inventory.delete_item(item)
      assert_raise Ecto.NoResultsError, fn -> Inventory.get_item!(item.id) end
    end

    test "change_item/1 returns a item changeset" do
      item = item_fixture()
      assert %Ecto.Changeset{} = Inventory.change_item(item)
    end
  end
end
