defmodule Drafter.Player do
  defstruct [:dm, :backlog, :picks, :uncracked, :left, :right]

  @typep dm :: Nostrum.Struct.Channel.dm_channel()
  @typep playerID :: integer()
  @typep seating :: {playerID(), playerID()}
  @type t :: %__MODULE__{
          dm: dm() | nil,
          backlog: [Card.pack()] | [] | nil,
          picks: [Card.t()] | [] | nil,
          uncracked: [Card.pack()] | [] | nil,
          left: playerID() | nil,
          right: playerID() | nil
        }

  # WTF DO I DO

  @spec seating_helper([playerID()]) :: [seating()]
  defp seating_helper([left_player | [me | [right_player | others]]] = _seating) do
    [{left_player, right_player} | seating_helper([me | [right_player | others]])]
  end

  @spec seating_helper([playerID()]) :: []
  defp seating_helper(_) do
    []
  end

  @spec seating([playerID]) :: [seating()]
  defp seating([first | _] = players) do
    players = [List.last(players) | players] ++ [first]
    seating_helper(players)
  end

  # THIS SHOULD IMPORT A TYPE FROM OUTSIDE
  @spec gen_helper([dm()], [Card.pack()], [seating()], any()) :: [__MODULE__.t()]
  def gen_helper([dm | rest_dms] = _dms, packs, [my_seating | rest] = _seating, "cube") do
    {mine, others} = Enum.split(packs, 3)
    {left, right} = my_seating

    [
      %Player{dm: dm, backlog: [], picks: [], uncracked: mine, left: left, right: right}
      | gen_helper(rest_dms, others, rest, "cube")
    ]
  end

  @spec gen_helper([dm()]) :: []
  def gen_helper(_dms, _packs, _seating, _opt) do
    []
  end

  @spec gen_dms([Nostrum.Struct.User.t()]) :: [dm()]
  def gen_dms([player | others] = _players) do
    {:ok, player_id} = Nostrum.Snowflake.cast(player)
    {:ok, dm} = Nostrum.Api.create_dm(player_id)
    [dm | gen_dms(others)]
  end

  @spec gen_dms([Nostrum.Struct.User.t()]) :: [dm()]
  def gen_dms([]) do
    []
  end

  @spec gen_players()
  def gen_players(set, "cube", group, loader_name) do
    dms = gen_dms(group)

    for dm <- dms,
        do:
          Nostrum.Api.create_message(
            dm.id,
            "welcome, packs will be constructed soon, 5-10s per player, sry :/"
          )

    seats = seating(group)
    cards = Enum.shuffle(set)
    packs = Card.gen_packs(cards, "cube", length(group) * 3, loader_name)
    player_info = gen_helper(dms, packs, seats, "cube")

    _players =
      Enum.zip([group, player_info])
      |> Map.new()
  end

  defp crack_pack(%Player{uncracked: [pack | rest]} = player) do
    _new_player =
      player
      |> Map.put(:backlog, [pack])
      |> Map.put(:uncracked, rest)
  end

  defp crack_pack(player) do
    player
  end

  def crack_all(players) do
    _new_players =
      players
      |> Enum.map(fn {k, v} -> {k, crack_pack(v)} end)
      |> Map.new()
  end

  def pull_direction(player, direction) do
    case direction do
      :left -> Map.get(player, :left)
      _ -> Map.get(player, :right)
    end
  end

  # takes a card out of a pack, card_index must be an integer
  def pick(playerID, card_index, players) do
    player = Map.get(players, playerID)

    case player do
      %Player{backlog: [pack | rest_packs], picks: picks} ->
        case List.pop_at(pack, card_index) do
          {nil, _} ->
            {:outofbounds, players}

          {card, new_pack} ->
            player =
              player
              |> Map.put(:picks, [card] ++ picks)
              |> Map.put(:backlog, [new_pack | rest_packs])

            players = Map.put(players, playerID, player)
            {:ok, players}
        end

      _ ->
        {:nopack, players}
    end
  end

  # passes current pack in a direction
  def pass_pack(playerID, direction, players) do
    player = Map.get(players, playerID)
    %Player{backlog: [pack | rest_packs]} = player
    player = Map.put(player, :backlog, rest_packs)

    players = Map.put(players, playerID, player)
    targetID = pull_direction(player, direction)
    target = Map.get(players, targetID)
    new_target_packs = Map.get(target, :backlog) ++ [pack]
    target = Map.put(target, :backlog, new_target_packs)

    _new_players =
      players
      |> Map.put(playerID, player)
      |> Map.put(targetID, target)
  end

  def text_picks(player) do
    message =
      player
      |> Map.get(:picks)
      |> Enum.map(fn card -> Map.get(card, :name) end)
      |> Enum.join("\n")

    {Map.get(player, :dm), message}
  end
end
