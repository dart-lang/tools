# `hello_world_app`

An application that uses the `hello_world` package and has a dependency on
`hello_world_german` such that when `hello_world` calls `findExtensions` it will
find the extension in `hello_world_german`.

**Notice**: This application only works when running from a project workspace.
See "runtime limitation" in the README for `package:extension_discovery`.
