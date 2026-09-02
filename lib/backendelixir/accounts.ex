defmodule Backendelixir.Accounts do
  @moduledoc """
  The Accounts context.
  Manages user authentication, registration, password verification, and native Phoenix.Token generation.
  """

  import Ecto.Query, warn: false
  alias Backendelixir.Repo
  alias Backendelixir.Accounts.User

  @token_salt "user_auth_salt_piura_transit"
  # Validez por defecto: 14 días en segundos
  @default_token_max_age 86_400 * 14

  @doc """
  Registers a new user and returns `{:ok, user}` or `{:error, changeset}`.
  """
  def register_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Authenticates a user by email and password using Pbkdf2 hash verification.
  """
  def authenticate_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = get_user_by_email(String.trim(email))

    cond do
      user && Pbkdf2.verify_pass(password, user.password_hash) ->
        {:ok, user}

      user ->
        {:error, :invalid_credentials}

      true ->
        Pbkdf2.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  @doc """
  Generates a cryptographically signed, stateless authentication token using Phoenix.Token.
  """
  def generate_user_token(%User{} = user) do
    payload = %{
      id: user.id,
      email: user.email,
      role: user.role,
      name: user.name
    }

    Phoenix.Token.sign(BackendelixirWeb.Endpoint, @token_salt, payload)
  end

  @doc """
  Verifies a Phoenix.Token and returns the user payload `{:ok, payload}` or `{:error, reason}`.
  """
  def verify_user_token(token, max_age \\ @default_token_max_age) when is_binary(token) do
    case Phoenix.Token.verify(BackendelixirWeb.Endpoint, @token_salt, token, max_age: max_age) do
      {:ok, %{id: user_id} = payload} ->
        # Opcionalmente se puede devolver el payload o cargar el usuario fresco desde BD
        case Repo.get(User, user_id) do
          nil -> {:error, :user_not_found}
          user -> {:ok, user, payload}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Gets a single user by ID.
  """
  def get_user!(id), do: Repo.get!(User, id)

  @doc """
  Gets a single user by ID or returns nil.
  """
  def get_user(id), do: Repo.get(User, id)

  @doc """
  Gets a user by email.
  """
  def get_user_by_email(email) when is_binary(email) do
    User
    |> where([u], u.email == ^email)
    |> Repo.one()
  end

  @doc """
  Returns all registered users.
  """
  def list_users do
    Repo.all(User)
  end
end
