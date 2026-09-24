# TypeMigrator

An Elixir project that translates `@spec` **TypeSpecs** annotations into
**Elixir Types** (the set-theoretic type system landing in Elixir's
experimental typechecker), and builds/analyses a dataset of real-world
translations to support the type-prediction work in
[`elixir_types_trainer`](../elixir_types_trainer).

This is the companion codebase for a Master's thesis (Ca' Foscari University
of Venice) on migrating dynamically-typed Elixir codebases toward the new
gradual, set-theoretic type system. See `thesis/main.pdf` (built from
`thesis/main.tex`) for the full write-up — translation formalisation,
dataset methodology, and the LLM type-prediction study.

## What's here

| Piece | Purpose |
|---|---|
| `lib/migrator/` | Core translator: parses a TypeSpec AST and produces the equivalent Elixir Types annotation (as a string, or as a `Module.Types.Descr` value). |
| `lib/mix/tasks/` | Mix tasks that drive the pipeline end-to-end (see below). |
| `lib/experiments/` | Dataset-construction, evaluation, and cascade-strategy modules backing the mix tasks (gitignored; internal to this checkout). |
| `example/` | Hand-written TypeSpec → Elixir Types examples, organised by type category, used as translator regression fixtures. |
| `results/dataset.jsonl` | The dataset produced by the pipeline: one entry per translated `@spec`, with Dialyzer and typechecker verdicts. Consumed by `elixir_types_trainer`. |
| `thesis/` | The LaTeX thesis itself. |
| `elixir/` | A local checkout of the custom Elixir compiler fork (not tracked in git — see Setup). |

## Requirements

- Erlang/OTP and Elixir pinned in `.tool-versions` (asdf/mise): `erlang 28.1`, `elixir 1.20.1`. This is the toolchain used to build and run this Mix project itself.
- A **separately built, custom Elixir compiler** with the experimental static typechecker — see below. Most mix tasks (`run_typecheck`, `eval_predictions`, `translate_dataset_types`, ...) shell out to this compiler; they will fail without it.
- Dialyzer (via the `dialyxir` dep, already in `mix.lock`).

### Building the custom Elixir compiler

`elixir/` is gitignored — it's a full checkout of
[`gldubc/elixir`](https://github.com/gldubc/elixir) (Guillaume Duboc's fork
implementing the set-theoretic type system this thesis builds on), not part
of this repo's history:

```bash
git clone https://github.com/gldubc/elixir.git
cd elixir
git checkout typespec-translation
make            # requires the Erlang/OTP version above
```

This produces the type-checking compiler at `elixir/bin/elixir` /
`elixir/bin/mix`, which the tasks below expect at that path relative to the
project root (some tasks accept an explicit `elixir/bin` override).

> Check `git diff` in a fresh checkout before relying on it as-is — this
> checkout has occasionally carried small local patches to
> `lib/elixir/lib/module/types/descr.ex` on top of the upstream branch.

## Setup

```bash
mix deps.get
mix test           # sanity check: translator unit tests, no custom compiler needed
```

## Pipeline

The mix tasks compose into the dataset-construction pipeline described in
the thesis (Chapter 2). Run in order over a directory of cloned open-source
Elixir repos:

```bash
# 1. Translate every @spec found under root_dir into Elixir Types
mix run_translation /path/to/repos

# 2. Cross-check each original @spec with Dialyzer
mix run_dialyzer /path/to/repos

# 3. Type-check the translated annotation with the custom compiler
mix run_typecheck /path/to/repos [elixir/bin]

# 4. Parse the accumulated results into results/dataset.jsonl (+ LaTeX stats)
mix run_dataset_parser [dataset.jsonl [output.tex]]
```

Downstream, once `elixir_types_trainer` has produced model predictions:

```bash
# Add each dataset entry's in-scope types translated to Elixir Types
# (feeds the Descr-track prompt in the trainer)
mix translate_dataset_types data/dataset.jsonl [out.jsonl]

# Typecheck LLM-predicted Elixir Types against the real project source
mix eval_predictions <set-theoretic|by-typecheck> <predictions.jsonl> [prjs_dir]
mix eval_predictions cascade <expanded.jsonl> <compact.jsonl>

# Score LLM-predicted TypeSpecs by translating them first, then comparing
mix eval_typespec_predictions <predictions.jsonl> [out.jsonl]
```

Run `mix help <task>` for any task's full usage; task moduledocs
(`lib/mix/tasks/*.ex`) are the source of truth.

`Migrator.main/1` (`lib/migrator.ex`) is also runnable directly for ad hoc
single-file translation:

```bash
mix run lib/migrator.ex descr_assert spec_file.ex type_file1.ex type_file2.ex ...
```

## Testing

```bash
mix test
```

Covers the translator (`lib/migrator/`) in isolation; it does not require
the custom compiler. Pipeline tasks that do (`run_typecheck`,
`eval_predictions`, `eval_typespec_predictions`, `translate_dataset_types`)
are exercised against real project checkouts rather than by the test suite.

## Related

- [`elixir_types_trainer`](../elixir_types_trainer) — fine-tunes and
  evaluates LLMs on the dataset this repo produces.
- [`gldubc/elixir`](https://github.com/gldubc/elixir) — the compiler fork
  supplying the Elixir Types typechecker.

## License

No license file is included; this is an academic thesis project. Contact
the author for reuse beyond the thesis's own citation.
