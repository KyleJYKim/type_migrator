defmodule TypeMigratorTest do
  @moduledoc false

  use ExUnit.Case, async: true
  doctest TypeMigrator
  #doctest TypeCheck.Internals.Parser

  #alias TypeCheck.Internals.Parser
  #alias TypeCheck.Builtin, as: B

  #alias TypeCheck.Internals.ParserTest.TypespecSample

  # test that fetch_spec doesn't explode and all specs are supported
  describe "fetch_spec smoke" do
    for module <- [Kernel, String, List, Enum, DateTime] do
      @module module
      for {func, arity} <- module.__info__(:functions) do
        @func func
        @arity arity
        test "#{module}.#{func}/#{arity}" do
          r = Parser.fetch_spec(@module, @func, @arity)
          refute match?({:error, "unsupported spec"}, r)
        end
      end
    end
  end
end
