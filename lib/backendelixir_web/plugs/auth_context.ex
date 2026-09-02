defmodule BackendelixirWeb.Plugs.AuthContext do
  @moduledoc """
  Plug that extracts and verifies Bearer tokens from the Authorization header,
  injecting `current_user` and `current_role` into the Absinthe context.
  """

  @behaviour Plug

  import Plug.Conn
  alias Backendelixir.Accounts

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    context = build_context(conn)
    Absinthe.Plug.put_options(conn, context: context)
  end

  defp build_context(conn) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user, _payload} <- Accounts.verify_user_token(String.trim(token)) do
      %{current_user: user, current_role: user.role}
    else
      _ ->
        %{current_user: nil, current_role: nil}
    end
  end
end
