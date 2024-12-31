# Security Policy

## Supported Versions

As this is the first public version of App Identity, security updates will be
applied on a rolling basis both to the specification and to the reference
implementations.

### Specification Support

The specification is a living document and is supported for two major versions
unless otherwise noted.

> Security reports for the version 1 algorithm will not be accepted. It has a
> well-known token lifetime issue and exists solely to provide support to
> already existing apps until they can be upgraded.

> A future version of the specification will shift from _recommending_ against
> the use of version 1 to _prohibiting_ the use of version 1.

### Reference Release Support

If there is a flaw in the specification, security releases will be made to the
two most recent major releases of each reference implementation that supports
the active specification version.

#### Example

If we have released versions 1.5.3, 2.3.4, and 3.2.1 of the Ruby reference
implementation which supports specification version 4, security updates will be
released for 2.3.x and 3.2.x only.

## Reporting a Vulnerability

## Security contact information

Please use the [Tidelift security contact][tidelift] for reporting security
vulnerabilities. Tidelift will coordinate the fix and disclosure.

Alternatively, security vulnerabilities may be sent to
[app\_identity@halostatue.ca][email] with the text `App Identity` in the
subject. They should be encrypted with [age][age] using the following public
key:

```
age1jx0sgpca62669tklat8js4e6xlsxhyy00ccl6y94txy3dtva7ymq44k7p6
```

[email]: mailto:app_identity@halostatue.ca
[age]: https://github.com/FiloSottile/age
[tidelift]: https://tidelift.com/security
