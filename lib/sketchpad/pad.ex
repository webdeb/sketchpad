defmodule Sketchpad.Pad do
  use GenServer
  alias Sketchpad.Web.PadChannel

  def find(pad_id) do
    case :global.whereis_name(pad_name(pad_id)) do
      pid when is_pid(pid) -> {:ok, pid}
      :undefined -> {:error, :noprocess}
    end
  end

  def put_stroke(from, server, pad_id, user_id, stroke) do
    GenServer.call(server, {:put_stroke, user_id, stroke})
    PadChannel.broadcast_stroke(from, pad_id, user_id, stroke)
  end

  def clear(from, server, pad_id) do
    :ok = GenServer.call(server, :clear)
    PadChannel.broadcast_clear(from, pad_id)
  end

  def render(server) do
    GenServer.call(server, :render)
  end

  defp pad_name(pad_id), do: "pad:#{pad_id}"

  def start_link(pad_id) do
    GenServer.start_link(__MODULE__, [pad_id],
      name: {:global, pad_name(pad_id)})
  end


  def init([pad_id]) do
    schedule_persist()
    {:ok, %{users: %{}, pad_id: pad_id}}
  end

  defp schedule_persist do
    Process.send_after(self(), :persist, 10_000)
  end

  def handle_info(:persist, state) do
    IO.puts (">> PERSISTING #{state.pad_id}")
    schedule_persist()
    {:noreply, state}
  end

  def handle_call({:put_stroke, user_id, stroke}, _from, state) do
    users =
      state.users
      |> Map.put_new(user_id, %{id: user_id, strokes: []})
      |> update_in([user_id, :strokes], fn strokes ->
        [stroke | strokes]
      end)

    {:reply, :ok, %{state | users: users}}
  end

  def handle_call(:render, _from, state) do
    {:reply, state.users, state}
  end

  def handle_call(:clear, _from, state) do
    {:reply, :ok, %{state | users: %{}}}
  end

end
