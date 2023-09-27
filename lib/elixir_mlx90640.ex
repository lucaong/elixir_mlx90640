defmodule Mlx90640 do
  @moduledoc """
  `elixir_mlx90640` provides a high level abstraction to interface with the
  MLX90640 Far Infrared Thermal Sensor Array on Linux platforms.
  """
  import Bitwise
  use GenServer

  defmodule State do
    @moduledoc false
    defstruct port: nil, receiver: nil
  end

  defmodule Frame do
    @moduledoc false
    defstruct data: []
  end

  @type frame_rate :: 1 | 2 | 4 | 8 | 16 | 32 | 64

  @doc """
  Starts and links the `Mlx90640` GenServer.

  `receiver` is a process that will receive messages on each frame captured by
  the sensor.

  `frame_rate` is the (approximate) number of frames per second that the sensor
  will capture. Valid values are 1, 2, 4, 8, 16, 32, and 64. The default is 2.
  Higher values might require a faster I2C baud rate to be configured in Linux.

  The `receiver` process will receive, for each frame captured by the sensor, a
  message like `%Mlx90640.Frame{ data: data }`, where `data` is a list of rows,
  and each row is a list of pixel temperature measurements, expressed as
  floating point numbers indicating the temperature in degrees Celsius.

  Under normal conditions, there should be 24 rows of 32 pixels each, but in
  case of corrupted data frames there might be less.
  """
  @spec start_link(pid, [ frame_rate: frame_rate ], [ term ]) :: GenServer.on_start()
  def start_link(receiver, mlx_opts \\ [], opts \\ []) do
    frame_rate = Keyword.get(mlx_opts, :frame_rate, 2)

    if Enum.member?([1, 2, 4, 8, 16, 32, 64], frame_rate) do
      arg = %{ receiver: receiver, frame_rate: frame_rate }
      GenServer.start_link(__MODULE__, arg, opts)
    else
      { :error, "frame rate #{frame_rate} not supported" }
    end
  end

  @doc """
  Gracefully stops the `Mlx90640` GenServer.
  """
  @spec stop(GenServer.server()) :: :ok
  def stop(pid) do
    GenServer.cast(pid, :stop)
  end

  # GenServer callbacks

  def init(%{ receiver: receiver, frame_rate: frame_rate }) do
    executable_dir = Application.get_env(:elixir_mlx90640, :executable_dir, :code.priv_dir(:elixir_mlx90640))

    port = Port.open({:spawn_executable, executable_dir ++ '/mlx90640'}, [
      {:args, ["#{frame_rate}"]},
      {:packet, 2},
      :use_stdio,
      :binary,
      :exit_status
    ])

    {:ok, %State{ port: port, receiver: receiver }}
  end

  def handle_info({port, {:data, data}}, state = %State{ port: port, receiver: receiver }) do
    send(receiver, %Frame{ data: decode(data) })
    { :noreply, state }
  end

  def handle_info({port, {:exit_status, exit_status}}, state = %State{ port: port }) do
    { :stop, exit_status, state }
  end

  def handle_cast(:stop, state) do
    { :stop, :normal, state }
  end

  # Private helper functions

  defp decode(data, decoded \\ []) do
    case data do
      <<>> -> decoded |> Enum.reverse |> Enum.chunk_every(32)
      << a, b, rest :: binary >> -> decode(rest, [decode_bytes(a, b) | decoded])
      _ -> nil
    end
  end

  defp decode_bytes(a, b) do
    sign = if bsr(band(b, 0b10000000), 7) == 1, do: -1, else: 1
    fractional = band(b, 0b01111111)
    (a * sign) + (sign * fractional / 100.0)
  end
end
