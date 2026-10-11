/**
 * Ambient type definitions for the Deno runtime in Supabase Edge Functions.
 * Provides editor type checking and auto-completion when the Deno LSP is not active.
 */
declare namespace Deno {
  export interface Env {
    get(key: string): string | undefined;
    set(key: string, value: string): void;
    delete(key: string): void;
    toObject(): Record<string, string>;
    has(key: string): boolean;
  }

  export const env: Env;

  export function serve(
    handler: (request: Request) => Response | Promise<Response>,
    options?: {
      port?: number;
      hostname?: string;
      onListen?: (localAddr: { port: number; hostname: string }) => void;
      onError?: (error: unknown) => Response | Promise<Response>;
    }
  ): void;
}
