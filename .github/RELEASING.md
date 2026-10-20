# Registering PerfectForms in General

The first release is `0.1.0`, as specified in `Project.toml`. Keep the existing
UUID `fb262a76-a2c1-4c0f-a19a-9a44622bb182` for all releases.

Registration lets Julia resolve `Pkg.add("PerfectForms")`. It distributes the
Julia package and exporter source; users still build and install the C++ backend
using the [README instructions](../README.md#build-options).
Loading `PerfectForms` must succeed before that installation. General checks
installation and loading, and permits functionality to require additional setup.
See [General's setup policy](https://github.com/JuliaRegistries/General#my-package-fails-to-load-because-it-needs-proprietary-softwareadditional-setup-to-work-what-can-i-do).

## Before the first registration

1. Review the release's code and documentation. General requires human
   understanding and review of AI-assisted code and asks for a README disclosure
   of substantial generated contributions. Check that our disclosure covers the
   contributions being released.
   See [General's policy](https://github.com/JuliaRegistries/General#is-there-any-policy-regarding-the-use-of-llms-in-registered-packages).
2. Commit and push the release preparation changes to `main`. Keep
   `version = "0.1.0"` until the first registration has merged. The name, UUID,
   license, repository layout and bounded Julia/JSON3 compatibility entries
   are already present; retain them. General runs the full
   [AutoMerge checks](https://juliaregistries.github.io/RegistryCI.jl/stable/guidelines/),
   including name similarity, on the registration PR.
3. Wait for [Build and test](https://github.com/dimpase/PerfectForms.jl/actions/workflows/ci.yml)
   to pass on the commit being registered. CI first instantiates and loads the
   Julia package with no backend installed, then builds the backend and runs
   the native and Julia tests.
4. [Install the JuliaRegistrator GitHub app](https://github.com/apps/juliateam-registrator/installations/new)
   for `dimpase/PerfectForms.jl`. If it is already installed on the account,
   ensure this repository is included.

## Submit version 0.1.0

Open the tested commit in
[the package's commit history](https://github.com/dimpase/PerfectForms.jl/commits/main)
and post this commit comment as a repository collaborator:

```text
@JuliaRegistrator register
```

Use the exact tested commit. The trigger belongs in the PerfectForms repository.
Registrator reads its `Project.toml` and opens a PR in General; follow the PR link
in the bot's reply. A Git tag or GitHub release is not needed beforehand.
See [Registrator's instructions](https://github.com/JuliaRegistries/Registrator.jl#via-the-github-app).

If checks fail, fix the problem, push a new commit, wait for its CI and comment
the same trigger on that commit. Keep `0.1.0` while correcting this pending
registration; Registrator updates the request.

New packages have a minimum three-day review period. Passing automatic checks
does not remove that wait, and reviewer feedback can extend it.
See [General's registration process](https://github.com/JuliaRegistries/General#registering-a-package-in-general).

## After the registration PR merges

Create the `v0.1.0` tag using the exact `git tag` command supplied by Registrator,
which identifies the registered commit, then publish the tag:

```bash
git push origin v0.1.0
```

This repository currently uses manual tagging. [TagBot](https://github.com/JuliaRegistries/TagBot)
can automate tags and GitHub releases later. Neither is required by Julia's
package manager.

Check registry installation from a fresh Julia environment, separate from the
development checkout:

```julia
using Pkg
Pkg.activate(; temp=true)
Pkg.Registry.update()
Pkg.add(name="PerfectForms", version="0.1.0")
using PerfectForms
```

Registry/package-server propagation can lag the merge. Retry after propagation
if the version is not yet available. To use an already installed backend, set
the configuration before calling `default_backend()`:

```julia
ENV["PERFECT_FORMS_BACKEND_CONFIG"] =
    expanduser("~/work/tmp/PerfectForms.jl/backend/config.json")
default_backend().executable
```

For later releases, update `Project.toml` to the next appropriate version,
commit and push, wait for CI, and trigger Registrator on that commit again.
Registered versions are immutable: publish a new version for subsequent fixes.
