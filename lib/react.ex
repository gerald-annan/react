defmodule React do
  @opaque cells :: pid

  @type cell :: {:input, String.t(), any} | {:output, String.t(), [String.t()], fun()}

  @doc """
  Start a reactive system
  """
  @spec new(cells :: [cell]) :: {:ok, pid}
  def new(cells) do
    {:ok, spawn(fn -> system(cells) end)}
  end

  def system(cells) do
    find = fn param ->
      Enum.find(cells, fn cell ->
        [_, key | _] = Tuple.to_list(cell)
        key == param
      end)
    end

    findm = fn param ->
      {_, ^param, [input], func} =
        Enum.find(cells, fn cell ->
          [_, key | _] = Tuple.to_list(cell)
          key == param
        end)

      {_, _, value} = find.(input)
      func.(value)
    end

    receive do
      {:get_value, "input", pid} ->
        {_, _, value} = find.("input")
        send(pid, {:response, value})
        system(cells)

      {:get_value, "output", pid} ->
        {_, _, input, func} = find.("output")

        case input do
          ["input"] ->
            {_, _, value} = find.("input")
            send(pid, {:response, func.(value)})
            system(cells)
          ["true", "value"] ->
            {_, _, condition} = find.("true")
            {_, _, value} = find.("value")
            send(pid, {:response, func.(condition, value)})
            system(cells)

          
        end

        system(cells)

      {:set_value, cell_name, value} ->
        Enum.map(cells, fn cell ->
          [_, key | _] = Tuple.to_list(cell)

          case key == cell_name do
            true -> put_elem(cell, 2, value)
            false -> cell
          end
        end)
        |> system()
    end
  end

  @doc """
  Return the value of an input or output cell
  """
  @spec get_value(cells :: pid, cell_name :: String.t()) :: any()
  def get_value(cells, cell_name) do
    send(cells, {:get_value, cell_name, self()})

    receive do
      {:response, value} ->
        value
    end
  end

  @doc """
  Set the value of an input cell
  """
  @spec set_value(cells :: pid, cell_name :: String.t(), value :: any) :: :ok
  def set_value(cells, cell_name, value) do
    send(cells, {:set_value, cell_name, value})
  end

  @doc """
  Add a callback to an output cell
  """
  @spec add_callback(
          cells :: pid,
          cell_name :: String.t(),
          callback_name :: String.t(),
          callback :: fun()
        ) :: :ok
  def add_callback(cells, cell_name, callback_name, callback) do
  end

  @doc """
  Remove a callback from an output cell
  """
  @spec remove_callback(cells :: pid, cell_name :: String.t(), callback_name :: String.t()) :: :ok
  def remove_callback(cells, cell_name, callback_name) do
  end
end
