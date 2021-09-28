defmodule FlowRunner.Spec.Flow do
  @moduledoc """
  A Flow is a set of connected blocks as defined by the Flow Spec.
  """
  use FlowRunner.SpecLoader,
    manual: [
      blocks: FlowRunner.Spec.Block
    ]

  defstruct uuid: nil,
            name: nil,
            label: nil,
            last_modified: nil,
            interaction_timeout: nil,
            vendor_metadata: nil,
            supported_modes: nil,
            first_block_id: nil,
            exit_block_id: nil,
            languages: [],
            blocks: []

  @type t :: %__MODULE__{
          uuid: String.t(),
          name: String.t(),
          label: String.t(),
          last_modified: String.t(),
          interaction_timeout: pos_integer(),
          vendor_metadata: map,
          supported_modes: [String.t()],
          first_block_id: String.t(),
          exit_block_id: String.t(),
          languages: [map],
          blocks: [Block.t()]
        }

  validates(:uuid, presence: true, uuid: [format: :default])

  def fetch_block(flow, block_uuid) when is_list(flow.blocks) do
    blocks = Enum.filter(flow.blocks, &(&1.uuid == block_uuid))

    if Enum.empty?(blocks) do
      {:error, "no block with uuid '#{block_uuid}' in flow '#{flow.uuid}'"}
    else
      {:ok, Enum.at(blocks, 0)}
    end
  end

  def fetch_block(_flow, _block_uuid) do
    {:error, "no blocks in flow"}
  end
end
