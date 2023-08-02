# `hello_world` package

Example of a package that can be extended, and uses `extension_discovery` to
find extensions.

## Limitations

The `sayHello` function in this package can only be used in a project workspace,
where dependencies are resolved and you're running in JIT-mode.

The `sayHello` function uses `findExtensions` and, thus, cannot be called in a
compiled Flutter application or AOT-compiled executable. For this to work, we'd
need to augment this package with code-generation, such that the code-generation
uses `findExtensions` and compiles a `sayHello` function into your application.

## Extending the `hello_world` package

Other packages can extend this package by providing an `extension/hello_world/config.json` file the following form:

```js
// extension/hello_world/config.json
{
  "language": "<language>",
  "message": "<message>"
}
```
