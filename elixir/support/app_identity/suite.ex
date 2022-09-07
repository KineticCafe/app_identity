defmodule AppIdentity.Suite do
  @moduledoc false

  @banner "#{AppIdentity.info(:name)} #{AppIdentity.info(:version)} (spec #{AppIdentity.info(:spec_version)}"

  def banner do
    @banner
  end

  if function_exported?(Kernel, :is_exception, 1) do
    def extract_message(term) when is_exception(term) do
      Exception.message(term)
    end

    def extract_message(term) do
      term
    end
  else
    def extract_message(term) do
      if Exception.exception?(term) do
        Exception.message(term)
      else
        term
      end
    end
  end

  # print_help is lifted from lib/mix/lib/mix/tasks/help.ex

  def print_help(module) do
    opts = Application.get_env(:mix, :colors)
    opts = [width: width(), enabled: ansi_docs?(opts)] ++ opts

    IO.ANSI.Docs.print_headings(["mix app_identity #{module.command()}"], opts)
    IO.ANSI.Docs.print(module.help(), "text/markdown", opts)
  end

  defp width do
    case :io.columns() do
      {:ok, width} -> min(width, 80)
      {:error, _} -> 80
    end
  end

  defp ansi_docs?(opts) do
    Keyword.get(opts, :enabled, IO.ANSI.enabled?())
  end
end
