defmodule ThousandIsland.Server do
  @moduledoc false

  use Supervisor

  @assert_type_form (dynamic() -> {:ok, pid()} or :ignore or {:error, {:already_started, pid()} or {:shutdown, term()} or term()})
  @spec start_link(ThousandIsland.ServerConfig.t()) :: Supervisor.on_start()
  def start_link(%ThousandIsland.ServerConfig{} = config) do
    Supervisor.start_link(__MODULE__, config, config.supervisor_options)
  end

  @assert_type_form (pid() or atom() or {:global, term()} or {:via, atom(), term()} or {atom(), atom()} -> pid() or :nil)
  @spec listener_pid(Supervisor.supervisor()) :: pid() | nil
  def listener_pid(supervisor) do
    supervisor
    |> Supervisor.which_children()
    |> Enum.find_value(fn
      {:listener, listener_pid, _, _} when is_pid(listener_pid) ->
        listener_pid

      _ ->
        false
    end)
  end

  @assert_type_form (pid() or atom() or {:global, term()} or {:via, atom(), term()} or {atom(), atom()} -> pid() or :nil)
  @spec acceptor_pool_supervisor_pid(Supervisor.supervisor()) :: pid() | nil
  def acceptor_pool_supervisor_pid(supervisor) do
    supervisor
    |> Supervisor.which_children()
    |> Enum.find_value(fn
      {:acceptor_pool_supervisor, acceptor_pool_sup_pid, _, _}
      when is_pid(acceptor_pool_sup_pid) ->
        acceptor_pool_sup_pid

      _ ->
        false
    end)
  end

  @assert_type_form (pid() or atom() or {:global, term()} or {:via, atom(), term()} or {atom(), atom()} -> :ok or :error)
  @spec suspend(Supervisor.supervisor()) :: :ok | :error
  def suspend(pid) do
    with pool_sup_pid when is_pid(pool_sup_pid) <- acceptor_pool_supervisor_pid(pid),
         :ok <- ThousandIsland.AcceptorPoolSupervisor.suspend(pool_sup_pid),
         :ok <- Supervisor.terminate_child(pid, :shutdown_listener),
         :ok <- Supervisor.terminate_child(pid, :listener) do
      :ok
    else
      _ -> :error
    end
  end

  @assert_type_form (pid() or atom() or {:global, term()} or {:via, atom(), term()} or {atom(), atom()} -> :ok or :error)
  @spec resume(Supervisor.supervisor()) :: :ok | :error
  def resume(pid) do
    with :ok <- wrap_restart_child(pid, :listener),
         :ok <- wrap_restart_child(pid, :shutdown_listener),
         pool_sup_pid when is_pid(pool_sup_pid) <- acceptor_pool_supervisor_pid(pid),
         :ok <- ThousandIsland.AcceptorPoolSupervisor.resume(pool_sup_pid) do
      :ok
    else
      _ -> :error
    end
  end

  defp wrap_restart_child(pid, id) do
    case Supervisor.restart_child(pid, id) do
      {:ok, _child} -> :ok
      {:error, reason} when reason in [:running, :restarting] -> :ok
      {:error, _reason} -> :error
    end
  end

  @impl Supervisor
  @assert_type_form (dynamic() -> {:ok, {%{:auto_shutdown => :never or :any_significant or :all_significant, :period => integer(), :intensity => integer(), :strategy => :one_for_one or :one_for_all or :rest_for_one}, empty_list() or non_empty_list(%{:significant => if_set(:false or :true), :modules => if_set(:dynamic or non_empty_list(atom(), empty_list()) or empty_list()), :type => if_set(:worker or :supervisor), :shutdown => if_set(:infinity or integer() or :brutal_kill), :restart => if_set(:permanent or :transient or :temporary), :start => {atom(), atom(), empty_list() or non_empty_list(term(), empty_list())}, :id => term()} or dynamic(), empty_list())}})
  @spec init(ThousandIsland.ServerConfig.t()) ::
          {:ok,
           {Supervisor.sup_flags(),
            [Supervisor.child_spec() | (old_erlang_child_spec :: :supervisor.child_spec())]}}
  def init(config) do
    ThousandIsland.ProcessLabel.set(:server, config)

    children = [
      {ThousandIsland.Listener, config} |> Supervisor.child_spec(id: :listener),
      {ThousandIsland.AcceptorPoolSupervisor, {self(), config}}
      |> Supervisor.child_spec(id: :acceptor_pool_supervisor),
      {ThousandIsland.ShutdownListener, {self(), config}}
      |> Supervisor.child_spec(id: :shutdown_listener)
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
