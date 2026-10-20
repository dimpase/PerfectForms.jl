module BuildPaths

using SHA, Scratch

const PACKAGE_UUID = Base.UUID("fb262a76-a2c1-4c0f-a19a-9a44622bb182")

# Separate versions and working checkouts, while retaining incremental builds
# when the contents of one checkout change.
function state_directory(package_root)
    identity = realpath(package_root) * "\0" *
               read(joinpath(package_root, "backend", "pins.json"), String)
    key = "backend-" * bytes2hex(sha256(identity))
    Scratch.get_scratch!(PACKAGE_UUID, key)
end

selection_file(package_root) = joinpath(state_directory(package_root), "selected.json")

end
