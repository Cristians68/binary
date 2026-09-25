// Keep these IDs in sync with CourseInfo.productId in lib/course_catalog.dart.
const COURSE_PRODUCTS = Object.freeze({
  binary_course_itsm: "itil-v4",
  binary_course_scrm: "csm",
  binary_course_netp: "binary-network-professional",
  binary_course_secp: "binary-cybersecurity-professional",
  binary_course_cldf: "binary-cloud-fundamentals",
  binary_course_clda: "binary-cloud-professional",
  binary_course_aiml: "binary-ai-fundamentals",
});
const LEGACY_SINGLE = "binary_course_single";
const BUNDLE4 = "binary_bundle_4";
const ALL = "binary_bundle_all";
const COURSE_IDS = new Set(Object.values(COURSE_PRODUCTS));
const isProduct = (id) => Object.hasOwn(COURSE_PRODUCTS, id) ||
  [LEGACY_SINGLE, BUNDLE4, ALL].includes(id);

class PurchaseError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}

function validCourses(ids, count) {
  return Array.isArray(ids) && ids.length === count &&
    new Set(ids).size === count && ids.every((id) => COURSE_IDS.has(id));
}

function checkoutSelection(data = {}) {
  const { productId, courseId, courseIds } = data;
  if (Object.hasOwn(COURSE_PRODUCTS, productId)) {
    if (courseId !== COURSE_PRODUCTS[productId] || courseIds != null) {
      throw new PurchaseError("invalid-argument", "Choose the course for this product.");
    }
    return { productId, courseIds: [courseId] };
  }
  if (productId === BUNDLE4 && validCourses(courseIds, 4) && courseId == null) {
    return { productId, courseIds: [...courseIds].sort() };
  }
  if (productId === ALL && courseId == null && courseIds == null) {
    return { productId, courseIds: [] };
  }
  if (productId === LEGACY_SINGLE || productId == null) {
    throw new PurchaseError("failed-precondition", "Update the app to buy a course. Existing purchases can still be restored.");
  }
  throw new PurchaseError("invalid-argument", "Choose a valid product and exactly four different courses for a bundle.");
}

module.exports = { COURSE_PRODUCTS, COURSE_IDS, LEGACY_SINGLE, BUNDLE4, ALL,
  isProduct, validCourses, checkoutSelection, PurchaseError };
