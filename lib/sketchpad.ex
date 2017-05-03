defmodule Sketchpad do
  @moduledoc """
  Collaborative Sketchpad.
  """

  use GenServer

  def start_link(initial_state \\ []) do
    GenServer.start_link(__MODULE__, initial_state)
  end
end
