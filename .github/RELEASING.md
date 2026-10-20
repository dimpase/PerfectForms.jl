# Registering PerfectForms in General

The first release is `0.1.0`, as specified in `Project.toml`. Keep the existing
UUID `fb262a76-a2c1-4c0f-a19a-9a44622bb182` for all releases.

Registration lets Julia resolve `Pkg.add("PerfectForms")`. Installation now runs
an automatic CMake source build through `deps/build.jl`; users must first install
the [native prerequisites](../docs/src/installation.md). Local patched upstream
checkouts are supported for development.
The [v0.1.0 registration review](https://github.com/JuliaRegistries/General/pull/172562#issuecomment-6289941736)
requests a Yggdrasil-built JLL so that normal installation supplies the backend.
The JLL work remains outstanding. Resolve with the reviewer whether this
automatic source-build workflow is acceptable for the initial release; do not
assume that it settles their request, or that the additional-setup policy alone
settles the review.

## Before the first registration

1. Review the release's code and documentation. General requires human
   understanding and review of AI-assisted code and asks for a README disclosure
   of substantial generated contributions. Check that our disclosure covers the
   contributions being released.
   See [General's policy](https://github.com/JuliaRegistries/General#is-there-any-policy-regarding-the-use-of-llms-in-registered-packages).
2. Commit and push the TagBot and Documentation workflows before making the
   commit submitted for registration. Keep workflow changes separate from that
   commit: GitHub restricts `GITHUB_TOKEN` from tagging or releasing commits that
   modify workflow files. See [TagBot's explanation](https://github.com/JuliaRegistries/TagBot#commits-that-modify-workflow-files).
3. Commit and push the release preparation changes to `main`. Keep
   `version = "0.1.0"` until the first registration has merged. The name, UUID,
   license, repository layout and bounded Julia/JSON3 compatibility entries
   are already present; retain them. General runs the full
   [AutoMerge checks](https://juliaregistries.github.io/RegistryCI.jl/stable/guidelines/),
   including name similarity, on the registration PR.
4. Wait for [Build and test](https://github.com/dimpase/PerfectForms.jl/actions/workflows/ci.yml)
   to pass on the commit being registered. CI first instantiates and loads the
   Julia package with native building explicitly skipped, then installs from Git
   in a fresh environment through `Pkg.add` and runs the native and Julia tests
   against its automatically selected scratch installation. The separate
   [Documentation workflow](https://github.com/dimpase/PerfectForms.jl/actions/workflows/documentation.yml)
   must also pass.
5. [Install the JuliaRegistrator GitHub app](https://github.com/apps/juliateam-registrator/installations/new)
   for `dimpase/PerfectForms.jl`. If it is already installed on the account,
   ensure this repository is included.

## TagBot and documentation setup

[TagBot.yml](workflows/TagBot.yml) listens for JuliaTagBot comments after
registration and can also be run manually from Actions. It has explicit
permissions to create tags, releases and failure-report issues, including when
the repository's default workflow permission is read-only. It does not submit
registrations.

For tags to trigger documentation builds automatically, add a write-enabled
SSH deploy key and store its private key as the `DOCUMENTER_KEY` Actions secret,
following [Documenter's key setup](https://documenter.juliadocs.org/stable/man/hosting/#Authentication:-SSH-Deploy-Keys).
The TagBot workflow already refers to that secret. Without it, ordinary tagging
still works, but the Documentation workflow must be run manually against the
release tag to publish versioned docs.

The Documentation workflow deploys with `GITHUB_TOKEN`. After its first push,
enable GitHub Pages on the `gh-pages` branch, root folder. Local build and
hosting instructions are in [Development](../docs/src/development.md).

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

Check that TagBot creates `v0.1.0` and its GitHub release. If it missed the
registration, run the TagBot workflow manually. For a workflow-changing release
that GitHub refuses to create automatically, follow TagBot's failure-report
issue; use Registrator's exact commit when creating the tag manually.
Neither the tag nor a GitHub release is required by Julia's package manager.

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
