defmodule React do
  @opaque cells :: pid

  @type cell :: {:input, String.t(), any} | {:output, String.t(), [String.t()], fun()}

  def find(cells, param) do
    Enum.find(cells, fn cell ->
      [_, input | _] = Tuple.to_list(cell)
      input == param
    end)
  end

  def send_callback(pid),
    do: fn name, value -> send(pid, {:callback, name, value}) end

  def react(cells, count \\ 0) do
    [cell | tail] = cells
    [param | _] = Tuple.to_list(cell)

    cell_by_value =
      case param == :input do
        true ->
          cell

        false ->
          [_, type, inputs, func | rest] = Tuple.to_list(cell)

          input_values =
            Enum.map(inputs, fn input ->
              return = find(cells, input)
              elem(return, tuple_size(return) - 1)
            end)

          case rest do
            [] ->
              {:output, type, inputs, func, output_value}

            [_] ->
              {:output, type, inputs, func, output_value}

            [current_value | callbacks] ->
              if current_value != output_value,
                do:
                  Enum.each(callbacks, fn [callback_name, callback] ->
                    callback.(callback_name, output_value)
                  end)

              {:output, type, inputs, func, output_value, callbacks}
          end
      end

    updated_cells = tail ++ [cell_by_value]

    if count < length(cells) do
      react(updated_cells, count + 1)
    else
      updated_cells
    end
  end

  @doc """
  Start a reactive system
  """
  @spec new(cells :: [cell]) :: {:ok, pid}
  def new(cells) do
    new_cells = react(cells, 0)
    {:ok, spawn(fn -> system(new_cells) end)}
  end

  def system(cells) do
    receive do
      {:get_value, "input", pid} ->
        {_, _, value} = find(cells, "input")
        send(pid, {:response, value})
        system(cells)

      {:get_value, "output", pid} ->
        {_, _, _, _, value} = find(cells, "output")
        send(pid, {:response, value})
        system(cells)

      {:set_value, cell_name, value} ->
        Enum.map(cells, fn cell ->
          [_, key | _] = Tuple.to_list(cell)

          case key == cell_name do
            true -> put_elem(cell, 2, value)
            false -> cell
          end
        end)
        |> react()
        |> system()

      {:add_callback, cell_name, callback_name, callback} ->
        Enum.map(cells, fn cell ->
          [_, key | _] = Tuple.to_list(cell)

          case key == cell_name do
            true ->
              newCell = Tuple.append(cell, [callback_name, callback])
              IO.inspect(newCell, label: :newCell)
              newCell

            false ->
              cell
          end
        end)
        |> system()

      {:remove_callback, cell_name, callback_name} ->
        Enum.map(cells, fn cell ->
          [_, key | _] = Tuple.to_list(cell)

          case key == cell_name do
            true ->
              [:output, "output", inputs, func, value | [callbacks]] = Tuple.to_list(cell)
              IO.inspect(cell, label: :cell)
              IO.inspect(callbacks, label: :callbacks)

              case callbacks do
                [] ->
                  cell

                _ ->
                  filtered =
                    Enum.filter(callbacks, fn [cname, _] ->
                      cname != callback_name
                    end)

                  IO.inspect(filtered, label: :filtered)
                  {:output, "output", inputs, func, value, filtered}
              end

            false ->
              cell
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
    send(cells, {:add_callback, cell_name, callback_name, callback})
  end

  @doc """
  Remove a callback from an output cell
  """
  @spec remove_callback(cells :: pid, cell_name :: String.t(), callback_name :: String.t()) :: :ok
  def remove_callback(cells, cell_name, callback_name) do
    send(cells, {:remove_callback, cell_name, callback_name})
  end
end

{:ok, cells} =
  React.new([
    {:input, "input", 11},
    {:output, "output", ["input"], fn a -> a + 1 end}
  ])

myself = self()
React.add_callback(cells, "output", "callback1", React.send_callback(myself))
React.add_callback(cells, "output", "callback2", React.send_callback(myself))
React.set_value(cells, "input", 31)
React.remove_callback(cells, "output", "callback1")
