# Roadmap

We're looking to enhance both the specification and implementations of App
Identity, but have not yet a specific plan or timeline for these.

## Known Issues

There are some known issues:

- Nominally, the `secret` value used in an app configuration can be any binary
  string value, but no work has been done to ensure that the reference
  implementations treat each of these values as binary values and not UTF-8
  strings, nor is the import or export of the app as JSON hardened to deal with
  non-UTF-8-safe values. Amongst other changes required:

  - Extend app initialization so that the `secret` can be initialized from an
    encoded value (e.g., `base64_secret`).

  - Change the JSON representation of app records to export `base64_secret` for
    the secret value.

## Improvements

Improvements under consideration include:

- Additional hashing algorithm support, such as SHA-3 variants. SHA-3 was only
  recently finalized and none of the reference languages have native support
  for the SHA-3 variants in their standard libraries.

- Parameter extension and shuffling. Although versions 2, 3, and 4 are resistant
  to replay attacks with the use of a verified timestamp nonce, it could be
  useful to have versions that can shuffle the parameters so that the position
  of the secret is not always in the same place during padlock hashing. That is,
  instead of the padlock ordered as `version id nonce padlock`, it might be
  `padlock nonce version id` or `nonce version id padlock` on a per-call basis,
  and the order of the parameters would indicate the order of the padlock
  parameters (e.g., `secret nonce id` and `nonce id secret`). This and other
  possible improvements would help fight key extension attacks.

- Multiple rounds. Some algorithm versions might provide multiple rounds of
  digest calculation putting the parameters in different (but defined) orders.
  This may not be compatible with the parameter shuffling option.
