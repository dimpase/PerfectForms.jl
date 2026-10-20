# Backend configuration

## Automatic selection

After a successful `Pkg.add` or `Pkg.build`, `default_backend()` finds the scratch
installation automatically. Selection order is:

1. The explicit `config_path` argument.
2. `ENV["PERFECT_FORMS_BACKEND_CONFIG"]`, if set to a nonempty value.
3. The last successful `Pkg.build` installation for the loaded package checkout/version.
4. `backend/config.json` in that package directory, for legacy/manual installs.

An unset or empty `PERFECT_FORMS_BACKEND_CONFIG` uses automatic selection.

A malformed or stale selected installation produces an error; it does not
silently fall back to another backend. Run `Pkg.build("PerfectForms"; verbose=true)`
to rebuild. Merely loading `PerfectForms` does not run a build.

## Select an installed backend explicitly

Set `PERFECT_FORMS_BACKEND_CONFIG` to the **absolute path of the installed
`config.json` file**. A value ending in `/backend` names a directory and causes the
`missing_executable` error even when the
executable has been installed.

For example, to select the checkout's installed backend explicitly, run in the
**shell before starting Julia**:

```bash
export PERFECT_FORMS_BACKEND_CONFIG="$HOME/work/tmp/PerfectForms.jl/backend/config.json"
```

For an **already-running Julia session**, change its own environment instead:

```julia
ENV["PERFECT_FORMS_BACKEND_CONFIG"] =
    expanduser("~/work/tmp/PerfectForms.jl/backend/config.json")
isfile(ENV["PERFECT_FORMS_BACKEND_CONFIG"])  # true
default_backend().executable
```

Shell changes do not update the environment of an already-running Julia
process. To return that session to automatic lookup, run:

```julia
delete!(ENV, "PERFECT_FORMS_BACKEND_CONFIG")
default_backend().executable
```

Use `expanduser` for `~` in Julia paths; a literal `"~/..."` is not absolute.

This selector also lets another copy of PerfectForms, such as an
ArithmeticVoronoi dependency, use an existing backend with the matching upstream
revision. To install in a separate location, run from the built checkout:

```bash
cmake --install build --prefix "$HOME/.local/opt/perfectforms"
export PERFECT_FORMS_BACKEND_CONFIG="$HOME/.local/opt/perfectforms/config.json"
```

## Troubleshooting

Inspect the path selected in the **Julia session that reports the error**:

```julia
using PerfectForms
@show pkgdir(PerfectForms)
selector = get(ENV, "PERFECT_FORMS_BACKEND_CONFIG", nothing)
@show selector
if selector !== nothing && !isempty(selector)
    @show isabspath(selector) isfile(selector)
end
default_backend().executable
```

If a nonempty override is set, both path checks should be `true`. With no override,
retry `Pkg.build("PerfectForms"; verbose=true)` and inspect its build log.

| Error | What to check |
| --- | --- |
| Julia cannot find `PerfectForms` | Start with `--project=` pointing to the environment where you used `Pkg.add` or `Pkg.develop`. |
| `config.json needs an absolute path` | The selector is relative. Use an absolute filename, or remove the override to use the default. |
| `missing_executable` | Build with `Pkg.build("PerfectForms"; verbose=true)`. If using a manual override, check that it names an existing `/config.json` file. |
| `invalid_executable: configure one absolute executable path` | The executable path inside the config is relative. Reinstall using an absolute prefix, as in [Installation](installation.md). |
| `executable hash differs from its configured build` | Reinstall the rebuilt executable to regenerate its configuration and hash. |
