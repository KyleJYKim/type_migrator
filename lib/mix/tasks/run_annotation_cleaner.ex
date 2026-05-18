defmodule Mix.Tasks.RunAnnotationCleaner do
  use Mix.Task
  @shortdoc "Remove @assert_type_form annotation"

  def run([path]) do
    AnnotationCleaner.main(path)
  end

  def run(_) do
    Mix.raise("Usage: mix run_annotation_cleaner [/path/to/root]")
  end
end
