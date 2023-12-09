defmodule Tests.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Tests.TestSupervisor.child_spec(nil)
    ]

    opts = [strategy: :one_for_one, name: Tests.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
