defmodule TestTest do
  use ExUnit.Case
  doctest Test

  describe "make_user ->" do
    test "creates a user" do
      Test.open(5, 2)

      {u1, s1} = Test.make_user
      assert u1 == 1
      assert s1[:user_id_seq] == 2
      assert s1[:users] == %{1 => []}

      {u2, s2} = Test.make_user
      assert u2 == 2
      assert s2[:user_id_seq] == 3
      assert s2[:users] == %{1 => [], 2 => []}
    end
  end

  describe "make_rover ->" do
    test "make rover inside map" do
      Test.open(5, 4)
      { u1, _} = Test.make_user

      { r1, s1} = Test.make_rover u1, 3, 1
      assert r1 == 1
      assert s1[:rover_id_seq] == 2
      assert s1[:rovers] == %{1 => {0, 3, 1}}
      assert s1[:map] == {
        {0, 0, 0, 0, 0},
        {0, 0, 0, 1, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0}
      }

      { r2, s2} = Test.make_rover u1, 3, 2
      assert r2 == 2
      assert s2[:rover_id_seq] == 3
      assert s2[:rovers] == %{1 => {0, 3, 1}, 2 => {0, 3, 2}}
      assert s2[:map] == {
        {0, 0, 0, 0, 0},
        {0, 0, 0, 1, 0},
        {0, 0, 0, 2, 0},
        {0, 0, 0, 0, 0}
      }
    end

    test "doesnt make rover outide map" do
      Test.open(5, 4)
      { u1, _} = Test.make_user
      assert Test.make_rover(u1, 5, 1) == :not_allowed
    end

    test "doesnt make rover for unfound users" do
      Test.open(5, 4)
      assert Test.make_rover(1, 1, 1) == :user_not_found
    end

    test "doesnt make rover in an occupied position" do
      Test.open(5, 4)
      { u1, _} = Test.make_user

      { r1, s1} = Test.make_rover u1, 3, 1
      assert r1 == 1
      assert s1[:rover_id_seq] == 2
      assert s1[:rovers] == %{1 => {0, 3, 1}}
      assert s1[:map] == {
        {0, 0, 0, 0, 0},
        {0, 0, 0, 1, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0}
      }

      assert Test.make_rover(u1, 3, 1) == :not_allowed
    end
  end

  describe "move ->" do
    test "moves to available spot" do
      Test.open(5, 4)
      { u1, _} = Test.make_user
      { r1, _} = Test.make_rover u1, 3, 1
      s1 = Test.move(u1, r1, "u")
      assert s1[:map] == {
        {0, 0, 0, 1, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0}
      }
      s2 = Test.move(u1, r1, "r")
      assert s2[:map] == {
        {0, 0, 0, 0, 1},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0}
      }
      s3 = Test.move(u1, r1, "d")
      assert s3[:map] == {
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 1},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0}
      }
      s4 = Test.move(u1, r1, "l")
      assert s4[:map] == {
        {0, 0, 0, 0, 0},
        {0, 0, 0, 1, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0}
      }
    end

    test "cannot move out of map" do
      Test.open(5, 4)
      { u1, _} = Test.make_user
      { r1, _} = Test.make_rover u1, 4, 1
      { r2, _} = Test.make_rover u1, 0, 1
      { r3, _} = Test.make_rover u1, 2, 0
      { r4, _} = Test.make_rover u1, 2, 3
      assert Test.move(u1, r1, "r") == :cannot_move_this_dir
      assert Test.move(u1, r2, "l") == :cannot_move_this_dir
      assert Test.move(u1, r3, "u") == :cannot_move_this_dir
      assert Test.move(u1, r4, "d") == :cannot_move_this_dir
    end

    test "cannot move to occupied pos" do
      Test.open(5, 4)
      { u1, _} = Test.make_user
      { r1, _} = Test.make_rover u1, 0, 0
      { r2, _} = Test.make_rover u1, 0, 1
      assert Test.move(u1, r1, "d") == :cannot_move_this_dir
    end

    test "cannot move others locked rovers" do
      Test.open(5, 4)
      { u1, _} = Test.make_user
      { u2, _} = Test.make_user
      { r1, _} = Test.make_rover u1, 2, 2

      Test.lock_rover(r1, u2)

      assert Test.move(u1, r1, "d") == :not_your_rover
      s1 = Test.move(u2, r1, "d")
      assert s1[:map] == {
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 1, 0, 0}
      }
    end
  end

  describe "lock_rover" do
    test "locks the rover for user" do
      Test.open(5, 4)
      { u1, _} = Test.make_user
      { r1, _} = Test.make_rover u1, 2, 2

      s = Test.lock_rover(r1, u1)
      assert s[:users] == %{1 => [1]}
      assert s[:rovers] == %{1 => {1, 2, 2}}
    end

    test "cannot lock another users rover" do
      Test.open(5, 4)
      { u1, _} = Test.make_user
      { u2, _} = Test.make_user
      { r1, _} = Test.make_rover u1, 2, 2

      Test.lock_rover(r1, u1)
      assert Test.lock_rover(r1, u2) == :someone_else_has_it
    end
  end

  describe "unlock_rover" do
    test "unlocks rover" do
      Test.open(5, 4)
      { u1, _} = Test.make_user
      { r1, _} = Test.make_rover u1, 2, 2

      Test.lock_rover(r1, u1)
      s = Test.unlock_rover(r1)
      assert s[:users] == %{1 => []}
      assert s[:rovers] == %{1 => {0, 1, 2}}
    end
  end
end
