defmodule Backendelixir.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items) do
      add :title, :string
      add :description, :string
      add :status, :string

      timestamps(type: :utc_datetime)
    end
  end
end
