defmodule Backendelixir.Repo.Migrations.CreateAuditLogs do
  use Ecto.Migration

  def change do
    create table(:audit_logs) do
      add :actor_id, references(:users, on_delete: :nilify_all)
      add :actor_role, :string
      add :actor_email, :string
      add :event_type, :string, null: false
      add :resource_type, :string
      add :resource_id, :string
      add :payload, :map, default: %{}
      add :ip_address, :string
      add :recorded_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:audit_logs, [:event_type])
    create index(:audit_logs, [:actor_id])
    create index(:audit_logs, [:resource_type, :resource_id])
    create index(:audit_logs, [:recorded_at])
  end
end
