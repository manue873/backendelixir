defmodule BackendelixirWeb.UserSocket do
  use Phoenix.Socket

  alias Backendelixir.Accounts

  ## Channels
  channel "transit:*", BackendelixirWeb.TransitChannel

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) when is_binary(token) do
    case Accounts.verify_user_token(token) do
      {:ok, user, _payload} ->
        {:ok,
         socket
         |> assign(:current_user, user)
         |> assign(:user_id, user.id)
         |> assign(:role, user.role)}

      {:error, _reason} ->
        :error
    end
  end

  @impl true
  def connect(_params, socket, _connect_info) do
    {:ok,
     socket
     |> assign(:current_user, nil)
     |> assign(:user_id, nil)
     |> assign(:role, "PASAJERO")}
  end

  @impl true
  def id(socket) do
    if user_id = socket.assigns[:user_id] do
      "user_socket:#{user_id}"
    else
      nil
    end
  end
end
