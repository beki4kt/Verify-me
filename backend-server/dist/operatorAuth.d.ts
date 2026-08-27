export interface OperatorCredentials {
    email: string;
    password: string;
    code: string;
}
export interface OperatorClaims {
    sub: string;
    role: "super_admin";
    iat: number;
    exp: number;
    jti: string;
}
export declare class OperatorConfigurationError extends Error {
    readonly code = "OPERATOR_NOT_CONFIGURED";
}
export declare class OperatorAuthenticationError extends Error {
    readonly code = "INVALID_OPERATOR_CREDENTIALS";
}
export declare function hashOperatorPassword(password: string, salt?: NonSharedBuffer): string;
export declare function verifyOperatorPassword(password: string, encoded: string): boolean;
export declare function totpCode(secret: string, nowMs?: number, stepOffset?: number): string;
export declare function verifyTotp(code: string, secret: string, nowMs?: number): boolean;
export declare function operatorIsConfigured(env?: NodeJS.ProcessEnv): boolean;
export declare function authenticateOperator(credentials: OperatorCredentials, env?: NodeJS.ProcessEnv, nowMs?: number): {
    token: string;
    claims: OperatorClaims;
};
export declare function verifyOperatorToken(token: string, env?: NodeJS.ProcessEnv, nowMs?: number): OperatorClaims;
//# sourceMappingURL=operatorAuth.d.ts.map