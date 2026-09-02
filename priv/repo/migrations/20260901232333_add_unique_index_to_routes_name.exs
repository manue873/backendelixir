defmodule Backendelixir.Repo.Migrations.AddUniqueIndexToRoutesName do
  use Ecto.Migration

  def change do
    create unique_index(:routes, [:name])
  end
end
