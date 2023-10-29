defmodule Test do
  use GenServer

  def test do
    Test.open(5, 2)
    { u1, _} = Test.make_user
    { r1, _ } = Test.make_rover 1, 1, 1
    { r2, _ } = Test.make_rover 1, 2, 1
    Test.move u1, r1, "u"
    Test.print
  end

  def open(x_size, y_size) do
    GenServer.start_link(__MODULE__, {x_size, y_size}, name: __MODULE__)
  end

  def make_user() do
    GenServer.call(__MODULE__, {:make_user})
  end

  def make_rover(user_id, x, y) do
    GenServer.call(__MODULE__, {:make_rover, user_id, x, y})
  end

  def move(user_id, rover_id, direction) do
    GenServer.call(__MODULE__, {:move, user_id, rover_id, direction})
  end

  def lock_rover(rover_id, user_id) do
    GenServer.call(__MODULE__, {:lock_rover, user_id, rover_id})
  end

  def unlock_rover(rover_id) do
    GenServer.call(__MODULE__, {:unlock_rover, rover_id})
  end

  def print() do
    GenServer.cast(__MODULE__, {:print})
  end

  def init({x, y}) do

    {
      :ok,
      %{
        # this gives a 2d array of size x*y with 0s
        map: Enum.reduce(0..(y-1), {}, fn (_i, acc) -> Tuple.append(acc, Tuple.duplicate(0, x)) end),
        users: %{}, # user_id: [locked rovers]
        rovers: %{}, # id: {user_id, x, y}
        rover_id_seq: 1,
        user_id_seq: 1
      }
    }
  end

  def handle_cast({:print}, state) do
    IO.inspect state
    {:noreply, state}
  end

  def handle_call({:make_user}, _from, state) do
    user_id = state[:user_id_seq]
    new_state = Map.merge(state, %{
      user_id_seq: user_id + 1,
      users: Map.put(state[:users], user_id, []),
    })

    {:reply, {user_id, new_state}, new_state}
  end

  def handle_call({:make_rover, user_id, x, y}, _from, state) do
    if !position_is_available(state[:map], x, y), do: raise "not_allowed"

    user = get_user(state, user_id)

    rover_id = state[:rover_id_seq]
    new_state = Map.merge(state, %{
      rover_id_seq: rover_id + 1,
      rovers: Map.put(state[:rovers], rover_id, {0, x, y}),
      map: set_in_map(state[:map], x, y, rover_id)
    })

    {:reply, {rover_id, new_state}, new_state}
  rescue
    e in RuntimeError -> {:reply, String.to_atom(e.message), state }
  end

  def handle_call({:lock_rover, user_id, rover_id}, _from, state) do
    rover = get_rover(state, rover_id)
    user = get_user(state, user_id)

    cond do
      elem(rover, 0) == 0 ->
        new_users = %{state[:users] | user_id => [rover_id | state[:users][user_id]]}
        new_rovers = %{state[:rovers] | rover_id => {user_id, elem(rover, 1), elem(rover, 2)}}
        new_state = Map.merge(state, %{ rovers: new_rovers, users: new_users })
        {:reply, new_state, new_state}
      elem(rover, 0) == user_id ->
        raise "already_own_rover"
      true ->
        raise "someone_else_has_it"
    end
  rescue
    e in RuntimeError -> {:reply, String.to_atom(e.message), state }
  end

  def handle_call({:unlock_rover, rover_id}, _from, state) do
    rover = get_rover(state, rover_id)
    owner_id = elem(rover, 0)
    if owner_id == 0 do
      {:reply, state, state }
    else
      new_users = %{state[:users] | owner_id => get_user(state, owner_id) -- [rover_id] }
      new_rovers = %{state[:rovers] | rover_id => {0, elem(rover, 0), elem(rover, 1)}}
      new_state = Map.merge(state, %{ rovers: new_rovers, users: new_users })
      {:reply, new_state, new_state}
    end
  rescue
    e in RuntimeError -> {:reply, String.to_atom(e.message), state }
  end

  def handle_call({:move, user_id, rover_id, dir}, _from, state) do
    rover = get_rover(state, rover_id)
    user = get_user(state, user_id)

    if !Enum.member?(["u", "d", "l", "r"], dir), do: raise "invalid_dir"

    owner = elem(rover, 0)
    if owner != 0 && owner != user_id, do: raise "not_your_rover"

    x = elem(rover, 1)
    y = elem(rover, 2)
    {new_x, new_y} = get_new_position(x, y, dir)
    if !position_is_available(state[:map], new_x, new_y), do: raise "cannot_move_this_dir"

    new_map = set_in_map(state[:map], x, y, 0)
    new_map = set_in_map(new_map, new_x, new_y, rover_id)

    new_rovers = %{ state[:rovers] | rover_id => {elem(rover, 0), new_x, new_y}}

    new_state = Map.merge(state, %{ map: new_map, rovers: new_rovers })

    {:reply, new_state, new_state}
  rescue
    e in RuntimeError -> {:reply, String.to_atom(e.message), state }
  end

  def get_user(state, user_id) do
    user = state[:users][user_id]
    if is_nil(user), do: raise "user_not_found"
    user
  end

  def get_rover(state, rover_id) do
    rover = state[:rovers][rover_id]
    if is_nil(rover), do: raise "rover_not_found"
    rover
  end

  def get_new_position(x, y, dir) do
    case dir do
      "u" -> {x, y - 1}
      "d" -> {x, y + 1}
      "l" -> {x - 1, y}
      "r" -> {x + 1, y}
    end
  end

  def position_is_available(map, x, y) do
    y_limit = tuple_size(map)
    x_limit = tuple_size(elem(map, 0))

    if x > -1 && x < x_limit && y > -1 && y < y_limit do
      val = map |> elem(y) |> elem(x)
      val == 0
    else
      false
    end
  end

  def set_in_map(map, x, y, val) do
    y_row = map |> elem(y)
    new_y_row = put_elem(y_row, x, val)
    put_elem(map, y, new_y_row)
  end

  def test do
    IO.puts "Testing Elixir 2"
  end
end
