export declare class SupabaseRpcError extends Error {
    readonly status: number;
    readonly code?: string | undefined;
    constructor(message: string, status: number, code?: string | undefined);
}
export declare function callServiceRpc<T>(functionName: string, params: Record<string, unknown>): Promise<T>;
//# sourceMappingURL=supabaseRpc.d.ts.map