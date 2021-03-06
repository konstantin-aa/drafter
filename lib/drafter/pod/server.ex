defmodule Drafter.Pod.Server do
  use GenServer

  alias Drafter.Structs.Player
  alias Drafter.Pod.Server.State

  @type pod_name :: atom()

  @spec start_link(pod_name(), any()) :: GenServer.on_start()
  def start_link(pod_name, {_set, _option, _group} = args) do
    GenServer.start_link(__MODULE__, args, name: pod_name)
  end

  @spec init({State.set(), State.option(), Player.group()}) :: {:ok, State.waiting_state()}
  def init({set, option, group}) do
    {:ok, State.init({set, option, group})}
  end

  # waiting
  @spec ready(pod_name(), Player.playerID(), State.channelID()) :: :ok
  def ready(pod_name, playerID, channelID) do
    GenServer.cast(pod_name, {:ready, playerID, channelID})
  end

  # running
  @spec pick(pod_name(), Player.playerID(), Player.card_index_string() | Player.card_index()) ::
          :ok
  def pick(pod_name, playerID, card_index) do
    # needs to pass channelID probably
    GenServer.cast(pod_name, {:pick, playerID, card_index})
  end

  @spec list_picks(pod_name(), Player.playerID()) :: :ok
  def list_picks(pod_name, playerID) do
    GenServer.cast(pod_name, {:list_picks, playerID})
  end

  # waiting state
  @spec handle_cast(any(), State.t()) :: {:noreply, State.t()}
  def handle_cast({:ready, playerID, channelID}, %{status: :waiting} = state) do
    {:noreply, State.ready(state, playerID, channelID)}
  end

  # running state
  def handle_cast({:pick, playerID, card_index}, %{status: :running} = state) do
    {:noreply, State.pick(state, playerID, card_index)}
  end

  def handle_cast({:list_picks, playerID}, %{status: :running} = state) do
    {:noreply, State.list_picks(state, playerID)}
  end

  def handle_cast(_, _) do
    {:noreply, :ignore}
  end

  # any state
  @spec handle_call(any(), any(), State.t()) :: {:reply, any(), State.t()}
  def handle_call({:state}, _from, state) do
    {:reply, state, state}
  end

  def handle_call(_, _from, state) do
    {:reply, "not the time!", state}
  end
end
