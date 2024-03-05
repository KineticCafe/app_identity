defmodule AppIdentity.Suite do
  @moduledoc false

  @banner "#{AppIdentity.info(:name)} #{AppIdentity.info(:version)} (spec #{AppIdentity.info(:spec_version)})"

  def banner do
    @banner
  end

  if macro_exported?(Kernel, :is_exception, 1) do
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

    print_headings(["mix app_identity #{module.command()}"], opts)
    print(module.help(), "text/markdown", opts)
  end

  if Version.compare(System.version(), "1.11.0") == :lt do
    def print(doc, _format, options) do
      IO.ANSI.Docs.print(doc, options)
    end

    def print_headings(headings, options) do
      IO.ANSI.Docs.print_heading(Enum.join(headings, "\n"), options)
    end
  else
    defdelegate print(doc, format, options), to: IO.ANSI.Docs
    defdelegate print_headings(headings, options), to: IO.ANSI.Docs
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
