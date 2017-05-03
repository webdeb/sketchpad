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
    schedule_png_outsource()
    {:ok, %{users: %{},
            pending_clear_user_ids: [],
            clear_timer: nil,
            pad_id: pad_id}}
  end

  defp schedule_png_outsource do
    Process.send_after(self(), :png_outsource, 3000)
  end

  def handle_info(:png_outsource, state) do
    case Sketchpad.Web.Presence.list("pad:#{state.pad_id}") do
      users when users == %{} -> :noop
      users ->
        {user_id, %{metas: [%{phx_ref: ref} | _]}} = Enum.random(users)
        PadChannel.broadcast_png_outsource(state.pad_id, ref)
    end

    schedule_png_outsource()
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

  def img_to_ascii(base64, pad_id) do

    with {:ok, decoded_img} <- Base.decode64(base64),
      {:ok, path} <- Briefly.create(),
      {:ok, jpg_path} <- Briefly.create(),
      :ok <- File.write(path, decoded_img),
      args = ["-background", "white", "-flatten", path, "jpg:" <> jpg_path],
      {"", 0} <- System.cmd("convert", args),
      {ascii, 0} <- System.cmd("jp2a", ["-i", jpg_path]) do
        :ets.insert(:pad_cache, {pad_id, base64})
        ascii
      else
        _ -> :error
      end
  end

  def fetch_png(pad_id) do
    :ets.lookup_element(:pad_cache, pad_id, 2)
  end

  defp table_name(pad_id), do: :pad_cache

end
