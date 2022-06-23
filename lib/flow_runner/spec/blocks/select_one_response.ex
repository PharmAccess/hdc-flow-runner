defmodule FlowRunner.Spec.Blocks.SelectOneResponse do
  @moduledoc """
  A specialisation of a block that sends users a set of options and
  waits for the user to come back with one of them.
  """
  @behaviour FlowRunner.Spec.Block
  alias FlowRunner.Context
  alias FlowRunner.Spec.Block
  alias FlowRunner.Spec.Flow

  @impl true
  def validate_config!(%{"prompt" => prompt, "choices" => choices}) when is_map(choices) do
    # Rewrite RC2 format to RC3 format
    validate_config!(%{
      "prompt" => prompt,
      "choices" =>
        Enum.map(choices, fn {label, resource_uuid} ->
          %{
            "name" => label,
            "test" => "block.response = #{inspect(label)}",
            "prompt" => resource_uuid
          }
        end)
    })
  end

  def validate_config!(%{"prompt" => prompt, "choices" => choices}) when is_list(choices) do
    with {:ok, choices} <- validate_choices(choices),
         {:ok, %{prompt: prompt}} <-
           Vex.validate(%{prompt: prompt}, prompt: [presence: true, uuid: true]) do
      %{prompt: prompt, choices: choices}
    else
      {:error, reasons} ->
        reasons =
          reasons
          |> Enum.map_join(", ", fn {:error, key, _rule, reason} ->
            "In #{Atom.to_string(key)}: #{reason}"
          end)

        raise reasons
    end
  end

  def validate_config!(_) do
    raise "invalid config, 'prompt' and 'choices' fields required"
  end

  defp validate_choices(choices) do
    {valid_choices, invalid_choices} =
      choices
      |> Enum.map(&validate_choice/1)
      |> Enum.split_with(fn
        {:ok, _choice} -> true
        {:error, _reason} -> false
      end)

    valid_choices_flatted =
      valid_choices
      |> Enum.map(fn {:ok, choice} -> choice end)

    invalid_choices_flattened =
      invalid_choices
      |> Enum.flat_map(fn {:error, reasons} -> reasons end)
      |> Enum.map(fn {:error, key, _rule, reason} ->
        "#{inspect(Atom.to_string(key))} #{reason}."
      end)

    if Enum.empty?(invalid_choices_flattened) do
      {:ok, valid_choices_flatted}
    else
      {:error, [{:error, :choices, nil, Enum.join(invalid_choices_flattened, "\n")}]}
    end
  end

  defp validate_choice(%{"name" => name, "test" => test, "prompt" => prompt}),
    do:
      Vex.validate(
        %{
          name: name,
          test: test,
          prompt: prompt
        },
        name: [presence: true],
        test: [presence: true],
        prompt: [presence: true, uuid: true]
      )

  defp validate_choice(_),
    do:
      {:error, [{:error, :choices, nil, "\"name\", \"test\", and \"prompt\" are all required."}]}

  @impl true
  def evaluate_incoming(container, flow, block, context) do
    {
      :ok,
      container,
      flow,
      block,
      %Context{context | waiting_for_user_input: true, last_block_uuid: block.uuid}
    }
  end

  @impl true
  @spec evaluate_outgoing(Flow.t(), Block.t(), Context.t(), String.t()) ::
          {:ok, String.t()} | {:invalid, String.t()}
  def evaluate_outgoing(flow, block, _context, user_input) do
    matched_option =
      Enum.find(block.config.choices, fn
        %{name: _name, test: test, prompt: _prompt} ->
          {:ok, value} =
            FlowRunner.evaluate_expression_block(test, %{
              "flow" => flow,
              "block" => %{"response" => user_input}
            })

          value
      end)

    if matched_option do
      {:ok, matched_option.name}
    else
      {:invalid, "No choice tests evaluated to true."}
    end
  end
end
