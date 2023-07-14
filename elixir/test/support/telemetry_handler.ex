defmodule AppIdentity.TelemetryHandler do
  @moduledoc """
  This utility module is used during tests to capture telemetry events and send
  them back to the test processes that registered the handler.

  Adapted from Oban.TelemetryHandler.
  """

  @methods [:generate_proof, :plug, :verify_proof]

  events =
    for method <- @methods, event <- [:start, :stop] do
      [:app_identity, method, event]
    end

  @events events

  def attach(name) do
    :telemetry.attach_many(name, @events, &__MODULE__.handle/4, self())
  end

  def handle([:app_identity, _, _] = event, measurements, meta, pid) do
    send(pid, {:event, event, measurements, meta})
  end
end
