defmodule Backendelixir.Streaming.Producer do
  @moduledoc """
  High-throughput GenStage producer for Broadway pipelines.
  Buffers incoming events in memory and fulfills demand with backpressure support.
  """

  use GenStage

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenStage.start_link(__MODULE__, opts, name: name)
  end

  def push_event(producer, event) do
    GenStage.cast(producer, {:push, event})
  end

  @impl true
  def init(opts) do
    if name = Keyword.get(opts, :name) do
      try do
        Process.register(self(), name)
      rescue
        _ -> :ok
      end
    end

    {:producer, {:queue.new(), 0}}
  end

  @impl true
  def handle_cast({:push, event}, {queue, demand}) do
    new_queue = :queue.in(event, queue)
    dispatch_events(new_queue, demand, [])
  end

  @impl true
  def handle_demand(incoming_demand, {queue, demand}) do
    total_demand = demand + incoming_demand
    dispatch_events(queue, total_demand, [])
  end

  defp dispatch_events(queue, demand, events) when demand > 0 do
    case :queue.out(queue) do
      {{:value, event}, new_queue} ->
        message = %Broadway.Message{
          data: event,
          acknowledger: {Broadway.NoopAcknowledger, :ack_id, :ack_data}
        }

        dispatch_events(new_queue, demand - 1, [message | events])

      {:empty, empty_queue} ->
        {:noreply, Enum.reverse(events), {empty_queue, demand}}
    end
  end

  defp dispatch_events(queue, 0, events) do
    {:noreply, Enum.reverse(events), {queue, 0}}
  end
end
