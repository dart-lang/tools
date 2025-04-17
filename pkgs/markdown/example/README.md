Commands must be executed from the `/markdown` directory.

Run locally with JavaScript development compiler:

```console
dart run build_runner serve example
```

Build production JS and WebAssembly:

```console
dart run build_runner build -o example:build --release
```
