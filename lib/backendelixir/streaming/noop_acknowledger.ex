defmodule Backendelixir.Streaming.NoopAcknowledger do
  @moduledoc """
  Broadway acknowledger that safely ignores acknowledgements for in-memory fire-and-forget streams.
  """
  @behaviour Broadway.Acknowledger

  @impl true
  def ack(_ack_ref, _successful, _failed) do
    :ok
  end
end
