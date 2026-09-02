defmodule BackendelixirWeb.Resolvers.AccountResolver do
  @moduledoc """
  Absinthe GraphQL Resolvers for User Authentication and Registration.
  """

  alias Backendelixir.Accounts
  alias Backendelixir.Accounts.User

  def register(_parent, %{input: input}, _resolution) do
    case Accounts.register_user(input) do
      {:ok, user} ->
        token = Accounts.generate_user_token(user)

        Backendelixir.Streaming.EventProducer.publish_audit_event("USER_REGISTERED", %{
          actor_id: user.id,
          actor_role: user.role,
          actor_email: user.email,
          resource_type: "User",
          resource_id: to_string(user.id),
          payload: %{role: user.role, email: user.email}
        })

        {:ok, %{user: user, token: token}}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, format_errors(changeset)}

      {:error, reason} ->
        {:error, to_string(reason)}
    end
  end

  def login(_parent, %{input: %{email: email, password: password}}, _resolution) do
    case Accounts.authenticate_by_email_and_password(email, password) do
      {:ok, user} ->
        token = Accounts.generate_user_token(user)

        Backendelixir.Streaming.EventProducer.publish_audit_event("USER_LOGGED_IN", %{
          actor_id: user.id,
          actor_role: user.role,
          actor_email: user.email,
          resource_type: "User",
          resource_id: to_string(user.id),
          payload: %{role: user.role}
        })

        {:ok, %{user: user, token: token}}

      {:error, :invalid_credentials} ->
        {:error, "Credenciales inválidas: correo o contraseña incorrectos"}
    end
  end

  def me(_parent, _args, %{context: %{current_user: %User{} = user}}) do
    {:ok, user}
  end

  def me(_parent, _args, _resolution) do
    {:error, "No autenticado: debe proporcionar un token válido en el header Authorization"}
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    |> Enum.map_join(", ", fn {field, errors} ->
      "#{field}: #{Enum.join(errors, "; ")}"
    end)
  end
end
