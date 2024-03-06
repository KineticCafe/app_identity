# Changelog

> This changelog tracks the changes to the App Identity specification,
> integration suite, and project as a whole. Each reference implementation has
> its own changelog:
>
> - [Elixir](elixir/Changelog.md)
> - [Ruby](ruby/Changelog.md)
> - [Typescript](ts/Changelog.md)

## 4.3 / 2024-03-13

### Spec

- Use [RFC 8174][rfc8174] formatting for [RFC 2119][rfc2119] keywords.

### Integration Suite

- Added support for explicitly testing upper-case and lower-case padlocks, as
  well as deliberately invalid (non-hex) padlocks. If an explicit padlock case
  is not specified, the suite should randomize the case of the generated
  padlock. Tests were added for these new case controls.

- Improved suite and test description.

- Upgraded `tapview` to version 1.12.

### Project

- Improved project documentation and consistency, added an explicit Contributing
  document.

## 4.2 / 2023-11-23

### Spec

- Reword several paragraphs for improved clarity.

- Improved typographic consistency.

- Reordered example code to show the Typescript versions _first_ as that is the
  code sample which is likely to be most approachable.

## 4.1 / 2023-07-07

### Spec

- Added security recommendations for the generation and in-memory use of
  application `secret` values by libraries.

## 4.0 / 2022-09-07

- Initial public release as specification version 4.

[rfc2119]: https://datatracker.ietf.org/doc/html/rfc2119
[rfc8174]: https://datatracker.ietf.org/doc/html/rfc8174
