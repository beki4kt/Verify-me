type Env = Record<string, string | undefined>;
export declare function inspectOriginal(bytes: Uint8Array): {
    mime: "image/jpeg" | "image/png";
    width: number;
    height: number;
} | null;
export declare function createEdgeReceiptEvidenceHandler(env: Env, transport?: typeof fetch): (req: Request) => Promise<Response>;
export {};
//# sourceMappingURL=edgeReceiptEvidence.d.ts.map