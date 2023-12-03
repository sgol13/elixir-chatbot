defmodule Tests.TestSupervisor do
  use DynamicSupervisor

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(spec) do
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def terminate_child(child_pid) do
    DynamicSupervisor.terminate_child(__MODULE__, child_pid)
  end

  def terminate_all_children() do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.each(fn {_, pid, _, _} -> terminate_child(pid) end)
  end
end
