defmodule Sketchpad.Web.PadChannel do
  use Sketchpad.Web, :channel
  alias Sketchpad.Web.Endpoint
  alias Sketchpad.Pad

  def broadcast_stroke(from, pad_id, user_id, stroke) do
    Endpoint.broadcast_from!(
      from,
      topic(pad_id),
      "stroke",
      %{ user_id: user_id, stroke: stroke })
  end

  def broadcast_clear(from, pad_id) do
    Endpoint.broadcast_from!(from, topic(pad_id), "clear", %{})
  end

  defp topic(pad_id), do: "pad:#{pad_id}"

  def join("pad:" <> pad_id, _params, socket) do
    {:ok, server} = Pad.find(pad_id)
    send self(), :after_join

    socket =
      socket
      |> assign(:pad_id, pad_id)
      |> assign(:server, server)

    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    server = socket.assigns.server
    for {user_id, %{strokes: strokes}} <- Pad.render(server) do
      for stroke <- Enum.reverse(strokes) do
        push socket, "socket", %{user_id: user_id, strokes: strokes}
      end
    end
  end

  def handle_in("stroke", data, socket) do
    %{pad_id: pad_id, user_id: user_id, server: server} = socket.assigns
    Pad.put_stroke(self(), server, pad_id, user_id, data)

    {:noreply, socket}
  end

  def handle_in("clear", _data, socket) do
    Pad.clear(self(), socket.assigns.server)
    {:reply, :ok, socket}
  end

  def handle_in("new_msg", %{ "body" => body }, socket) do
    broadcast! socket, "new_msg", %{
      user_id: socket.assigns.user_id,
      body: body
    }
    {:reply, :ok, socket}
  end
end
