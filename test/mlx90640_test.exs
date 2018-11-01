defmodule Mlx90640Test do
  use ExUnit.Case
  doctest Mlx90640

  test "returns error if an invalid frame rate is chosen" do
    invalid_frame_rate = 123
    assert { :error, "frame rate #{invalid_frame_rate} not supported" } ==
      Mlx90640.start_link(self(), [frame_rate: invalid_frame_rate])
  end

  test "forwards parsed frames to receiver as list of pixel rows" do
    test_executable = './test/test_executable.sh'
    { :ok, _ } = Mlx90640.start_link(self(), [ __test_exe: test_executable, frame_rate: 8 ])
    assert_receive %Mlx90640.Frame{ data: data }, 2000

    expected_row = [27.73, -46.73] |> List.duplicate(16) |> List.flatten
    expected_rows = expected_row |> List.duplicate(24)
    assert data == expected_rows
  end
end
