"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OwnedVerifierError = void 0;
class OwnedVerifierError extends Error {
    constructor(message, code = "PROVIDER_UNAVAILABLE", status = 502, retryable = true) {
        super(message);
        this.code = code;
        this.status = status;
        this.retryable = retryable;
        this.name = "OwnedVerifierError";
    }
}
exports.OwnedVerifierError = OwnedVerifierError;
//# sourceMappingURL=types.js.map