# Elixir MLX90640

An Elixir library to interface with the MLX90640 Far Infrared Thermal Sensor Array.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `elixir_mlx90640` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:elixir_mlx90640, "~> 0.1.0"}
  ]
end
```

## Usage

```elixir
receiver = self() # a process that will receive the data frames
Mlx90640.start_link(receiver, [ frame_rate: 2 ])

# On each frame, the receiver will receive messages like:
#
#   %Mlx90640.Frame{ data: [ [ 23.83, 24.12, ... ], [ ... ] ] }
#
# Where data is a list of 24 rows, and rows are list of 32 temperature
# measurements
```

## Acknowledgements

This project contains low-level code derived from the device library provided by
Melexis at https://github.com/melexis/mlx90640-library , as well as the generic
Linux port provided by Pimoroni at https://github.com/pimoroni/mlx90640-library
