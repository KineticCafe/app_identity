# Security Policy

## Supported Versions

As this is the first public version of App Identity, security updates will be
applied on a rolling basis both to the specification and to the reference
implementations.

### Specification Support

The specification is a living document and is supported for two major versions
unless otherwise noted.

> Security reports for the version 1 algorithm will not be accepted. It has
> a well-known issue and exists solely to provide support to already existing
> apps until they can be upgraded. A future version of the specification will
> shift from _recommending_ against the use of version 1 to actively
> _prohibiting_ the use of version 1.

### Reference Release Support

If there is a flaw in the specification, security releases will be made to the
two most recent major releases of each reference implementation that supports
the active specification version.

#### Example

If we have released versions 1.5.3, 2.3.4, and 3.2.1 of the Ruby reference
implementation which supports specification version 4, security updates will be
released for 2.3.x and 3.2.x only.

## Reporting a Vulnerability

Report security vulnerabilities to [security@kineticcommerce.com][]. Emails sent
to this address should be encrypted using [age][] or [GnuPG][].

### age Public Key

```
age1cqu29vkj9s9f6l4cskj9q4ph7tfq43cem09gun7wym7k00aam90qz05xdd
```

### GnuPG Public Key

**Fingerprint**:

```
D9A2 8F3E 4516 584A 73B3  27C9 83BE 165E 3FBC 4469
```

**Public Key**:

```
-----BEGIN PGP PUBLIC KEY BLOCK-----

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
=5jMo
-----END PGP PUBLIC KEY BLOCK-----
```

[security@kineticcommerce.com]: mailto:security@kineticcommerce.com
[age]: https://github.com/FiloSottile/age
[gnupg]: https://gnupg.org
