defmodule BackendelixirWeb.ChannelCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import BackendelixirWeb.ChannelCase

      # The default endpoint for testing
      @endpoint BackendelixirWeb.Endpoint
    end
  end

  setup tags do
    Backendelixir.DataCase.setup_sandbox(tags)
    :ok
  end
end
