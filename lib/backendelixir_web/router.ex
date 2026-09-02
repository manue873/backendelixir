defmodule BackendelixirWeb.Router do
  use BackendelixirWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :graphql do
    plug :accepts, ["json"]
    plug BackendelixirWeb.Plugs.AuthContext
  end

  scope "/api" do
    pipe_through :graphql

    forward "/graphql", Absinthe.Plug, schema: BackendelixirWeb.Schema

    forward "/graphiql", Absinthe.Plug.GraphiQL,
      schema: BackendelixirWeb.Schema,
      interface: :playground,
      socket: BackendelixirWeb.UserSocket
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:backendelixir, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: BackendelixirWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
