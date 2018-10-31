defmodule Mlx90640 do
  use Bitwise
  use GenServer

  defmodule State do
    @moduledoc false
    defstruct port: nil, receiver: nil
  end

  defmodule Frame do
    @moduledoc false
    defstruct data: []
  end

  def start_link(receiver, mlx_opts \\ [], opts \\ []) do
    frame_rate = Keyword.get(mlx_opts, :frame_rate, 2)
    if Enum.member?([1, 2, 4, 8, 16, 32, 64], frame_rate) do
      GenServer.start_link(__MODULE__, [receiver, frame_rate], opts)
    else
      { :error, "frame rate #{frame_rate} not supported" }
    end
  end

  def stop(pid) do
    GenServer.cast(pid, :stop)
  end

  def init([receiver, frame_rate]) do
    executable = :code.priv_dir(:elixir_mlx90640) ++ '/mlx90640'

    port = Port.open({:spawn_executable, executable}, [
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

  def handle_cast(:stop, state) do
    { :stop, :normal, state }
  end

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
    (a * sign) + (fractional / 100.0)
  end
end
