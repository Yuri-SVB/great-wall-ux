# great-wall-ux

The visual and interaction layer of the Great Wall fractal encoder — a
Dart + Flutter library. The determinism-critical engine itself
(`escape_count`, encode, decode, Argon2, bisection) lives in
`great-wall-core` and is reached over FFI; this library never duplicates
the math.

## Documentation

The authoritative specification, invariants, and development guide live in
the vendored `great-wall-docs` submodule (repo:
[`yuri-svb/great-wall-docs`](https://github.com/yuri-svb/great-wall-docs)):

- [`great-wall-docs/great-wall-ux/SCOPE.md`](great-wall-docs/great-wall-ux/SCOPE.md)
  — what is in and out of scope, invariants
- [`great-wall-docs/great-wall-ux/TECH_STACK.md`](great-wall-docs/great-wall-ux/TECH_STACK.md)
  — Dart/Flutter decision and locked sub-decisions
- [`great-wall-docs/great-wall-ux/DEVELOPMENT.md`](great-wall-docs/great-wall-ux/DEVELOPMENT.md)
  — prerequisites, running the example, tests
- [`great-wall-docs/great-wallet/ARCHITECTURE.md`](great-wall-docs/great-wallet/ARCHITECTURE.md)
  — ecosystem-wide context

Clone with submodules:

```
git clone --recursive <url>
# or, after a flat clone:
git submodule update --init --recursive
```

## License

Dual-licensed under either of [Apache-2.0](LICENSE-APACHE) or
[MIT](LICENSE-MIT) at your option.
