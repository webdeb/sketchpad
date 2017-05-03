defmodule Sketchpad.Web.PadChannel do
  use Sketchpad.Web, :channel

  def join("pad:" <> pad_id, _params, socket) do
    {:ok, %{data: %{}}, socket}
  end

  def handle_in("stroke", data, socket) do
    broadcast_from! socket, "stroke", %{
      user_id: socket.assigns.user_id,
      stroke: data
    }

    {:noreply, socket}
  end

  def handle_in("clear", data, socket) do
    broadcast_from! socket, "clear", %{}
    {:reply, socket}
  end

  def handle_in("new_msg", %{ "body" => body }, socket) do
    broadcast! socket, "new_msg", %{
      user_id: socket.assigns.user_id,
      body: body
    }
    {:reply, :ok, socket}
  end
end
