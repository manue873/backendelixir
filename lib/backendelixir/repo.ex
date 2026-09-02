defmodule Backendelixir.Repo do
  use Ecto.Repo,
    otp_app: :backendelixir,
    adapter: Ecto.Adapters.Postgres
end
