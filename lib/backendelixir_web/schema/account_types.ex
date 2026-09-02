defmodule BackendelixirWeb.Schema.AccountTypes do
  use Absinthe.Schema.Notation

  enum :user_role do
    value(:conductor, as: "CONDUCTOR", description: "Conductor / Chofer de unidad de transporte")
    value(:pasajero, as: "PASAJERO", description: "Pasajero / Usuario ciudadano")
    value(:admin, as: "ADMIN", description: "Administrador del sistema de tránsito")
  end

  object :user do
    field :id, non_null(:id)
    field :email, non_null(:string)
    field :name, non_null(:string)
    field :role, non_null(:user_role)
    field :inserted_at, non_null(:string)
  end

  object :session_payload do
    field :user, non_null(:user)

    field :token, non_null(:string),
      description: "Token criptográfico nativo de Phoenix para autenticación"
  end

  input_object :register_input do
    field :email, non_null(:string)
    field :name, non_null(:string)
    field :password, non_null(:string)
    field :role, :user_role
  end

  input_object :login_input do
    field :email, non_null(:string)
    field :password, non_null(:string)
  end
end
