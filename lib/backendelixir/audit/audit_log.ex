defmodule Backendelixir.Audit.AuditLog do
  use Ecto.Schema
  import Ecto.Changeset

  @derive {Jason.Encoder,
           only: [
             :id,
             :actor_id,
             :actor_role,
             :actor_email,
             :event_type,
             :resource_type,
             :resource_id,
             :payload,
             :ip_address,
             :recorded_at,
             :inserted_at
           ]}
  schema "audit_logs" do
    field :actor_role, :string
    field :actor_email, :string
    field :event_type, :string
    field :resource_type, :string
    field :resource_id, :string
    field :payload, :map, default: %{}
    field :ip_address, :string
    field :recorded_at, :utc_datetime

    belongs_to :actor, Backendelixir.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def changeset(audit_log, attrs) do
    audit_log
    |> cast(attrs, [
      :actor_id,
      :actor_role,
      :actor_email,
      :event_type,
      :resource_type,
      :resource_id,
      :payload,
      :ip_address,
      :recorded_at
    ])
    |> validate_required([:event_type, :recorded_at])
  end
end
