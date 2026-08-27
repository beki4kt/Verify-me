"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __exportStar = (this && this.__exportStar) || function(m, exports) {
    for (var p in m) if (p !== "default" && !Object.prototype.hasOwnProperty.call(exports, p)) __createBinding(exports, m, p);
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.verifyWithOwnedRoute = verifyWithOwnedRoute;
const cbe_1 = require("./cbe");
const otherProviders_1 = require("./otherProviders");
const telebirr_1 = require("./telebirr");
__exportStar(require("./cbe"), exports);
__exportStar(require("./common"), exports);
__exportStar(require("./otherProviders"), exports);
__exportStar(require("./telebirr"), exports);
__exportStar(require("./types"), exports);
async function verifyWithOwnedRoute(provider, input) {
    const reference = (input.reference ?? input.receiptNumber ?? "").trim();
    switch (provider) {
        case "telebirr":
            return (0, telebirr_1.verifyTelebirrOwned)(reference);
        case "cbe":
            return (0, cbe_1.verifyCbeOwned)(reference, input.suffix);
        case "cbebirr": {
            const phone = (input.phoneNumber ?? "")
                .replace(/[\s()+-]/g, "")
                .replace(/^0/, "251");
            return (0, otherProviders_1.verifyCbeBirrOwned)(reference, phone);
        }
        case "dashen":
            return (0, otherProviders_1.verifyDashenOwned)(reference);
        case "abyssinia":
            return (0, otherProviders_1.verifyAbyssiniaOwned)(reference, input.suffix ?? "");
        case "mpesa":
            return (0, otherProviders_1.verifyMpesaOwned)(reference);
    }
}
//# sourceMappingURL=index.js.map