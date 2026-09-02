defmodule Backendelixir.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @roles ["CONDUCTOR", "PASAJERO", "ADMIN"]

  @derive {Jason.Encoder, only: [:id, :email, :name, :role, :inserted_at, :updated_at]}
  schema "users" do
    field :email, :string
    field :name, :string
    field :role, :string, default: "PASAJERO"
    field :password_hash, :string

    field :password, :string, virtual: true

    timestamps(type: :utc_datetime)
  end

  @doc """
  Changeset para registro de nuevo usuario con encriptación de contraseña.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :name, :role, :password])
    |> validate_required([:email, :name, :password])
    |> validate_email()
    |> validate_password()
    |> validate_role()
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
      message: "formato de correo electrónico inválido"
    )
    |> validate_length(:email, max: 160)
  end

  defp validate_password(changeset) do
    changeset
    |> validate_length(:password, min: 6, max: 72, message: "debe tener entre 6 y 72 caracteres")
  end

  defp validate_role(changeset) do
    changeset
    |> validate_inclusion(:role, @roles, message: "debe ser CONDUCTOR, PASAJERO o ADMIN")
  end

  defp put_password_hash(changeset) do
    case get_change(changeset, :password) do
      nil ->
        changeset

      password ->
        put_change(changeset, :password_hash, Pbkdf2.hash_pwd_salt(password))
        |> delete_change(:password)
    end
  end

  def valid_roles, do: @roles
end
