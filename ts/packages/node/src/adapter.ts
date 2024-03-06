import { createHash, randomUUID } from 'node:crypto'
import * as base64 from '@juanelas/base64'
import { RuntimeAdapter, setRuntimeAdapter } from '@kineticcafe/app-identity'

/**
 * The runtime adapter for Node.js environments.
 */
class NodeAdapter extends RuntimeAdapter {
  decodeBase64Url(value: string): null | string | undefined {
    try {
      return base64.decode(value, true)
    } catch (_) {
      return undefined
    }
  }

  encodeBase64Url(value: string): null | string | undefined {
    try {
      return base64.encode(value, true, true)
    } catch (_) {
      return undefined
    }
  }

  randomNonceString(): string {
    return randomUUID()
  }

  sha256(value: string): string {
    return this.makeHash(value, 'sha256')
  }

  sha384(value: string): string {
    return this.makeHash(value, 'sha384')
  }

  sha512(value: string): string {
    return this.makeHash(value, 'sha512')
  }

  private makeHash(value: string, algorithm: 'sha256' | 'sha384' | 'sha512'): string {
    const hash = createHash(algorithm)
    hash.update(value)
    return hash.digest('hex').toUpperCase()
  }
}

export const useNodeRuntimeAdapter = () => setRuntimeAdapter(NodeAdapter)
