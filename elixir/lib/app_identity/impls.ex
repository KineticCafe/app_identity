alias AppIdentity.{App, Proof}

if Code.ensure_loaded?(Poison) do
  defimpl Poison.Encoder, for: App do
    def encode(%App{} = app, opts) do
      app
      |> App.__to_map()
      |> Poison.Encoder.Map.encode(opts)
    end
  end

  defimpl Poison.Encoder, for: Proof do
    def encode(%Proof{} = proof, opts) do
      proof
      |> Map.from_struct()
      |> Poison.Encoder.Map.encode(opts)
    end
  end
end

if Code.ensure_loaded?(Jason) do
  defimpl Jason.Encoder, for: App do
    def encode(%App{} = app, opts) do
      app
      |> App.__to_map()
      |> Jason.Encode.map(opts)
    end
  end

  defimpl Jason.Encoder, for: Proof do
    def encode(%Proof{} = proof, opts) do
      proof
      |> Map.from_struct()
      |> Jason.Encode.map(opts)
    end
  end
end
