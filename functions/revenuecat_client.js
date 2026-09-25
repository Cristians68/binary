const { PurchaseError } = require("./purchase_catalog");

// Server only. Never pass this key, RevenueCat response, or upstream error body
// to the app or logs (subscriber attributes can contain personal information).
async function fetchCustomer(uid, apiKey, fetchImpl = fetch) {
  if (typeof apiKey !== "string" || !apiKey.startsWith("sk_")) {
    throw new PurchaseError("failed-precondition", "Purchases are temporarily unavailable. Please try again later.");
  }
  try {
    const response = await fetchImpl(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(uid)}`,
      {
        headers: { Authorization: `Bearer ${apiKey}`, Accept: "application/json" },
        signal: AbortSignal.timeout(8000),
        redirect: "error",
      }
    );
    if (!response.ok) {
      throw new PurchaseError("unavailable", "Could not verify purchases. Please try again shortly.");
    }
    return await response.json();
  } catch (error) {
    if (error instanceof PurchaseError) throw error;
    throw new PurchaseError("unavailable", "Could not verify purchases. Check your connection and try again.");
  }
}

module.exports = { fetchCustomer };
