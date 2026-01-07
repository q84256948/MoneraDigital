/**
 * Redirect path validator to prevent Open Redirect vulnerabilities
 *
 * This module validates redirect paths to ensure they only point to
 * internal application routes. Prevents attackers from using the
 * application as a vector for phishing attacks via open redirects.
 *
 * @see https://cheatsheetseries.owasp.org/cheatsheets/Unvalidated_Redirects_and_Forwards_Cheat_Sheet.html
 */

/**
 * List of allowed redirect paths within the application
 * Only internal routes should be included here
 */
const ALLOWED_REDIRECT_PATHS = [
  "/",
  "/dashboard",
  "/dashboard/lending",
  "/dashboard/assets",
  "/dashboard/security",
  "/dashboard/addresses",
  "/dashboard/withdraw",
  "/dashboard/statements",
] as const;

/**
 * Validates a redirect path to prevent Open Redirect attacks
 *
 * Security checks performed:
 * 1. Ensures path is a string (prevents null/undefined)
 * 2. Ensures path starts with "/" (blocks absolute URLs like "https://evil.com")
 * 3. Ensures path is in the whitelist of allowed routes
 * 4. Falls back to "/dashboard" for any invalid input
 *
 * @param path - The redirect path to validate
 * @returns A safe redirect path guaranteed to be an internal route
 *
 * @example
 * // Valid cases
 * validateRedirectPath("/dashboard/lending") // returns "/dashboard/lending"
 * validateRedirectPath("/dashboard") // returns "/dashboard"
 *
 * // Invalid cases (all return default "/dashboard")
 * validateRedirectPath("https://evil.com/phishing") // returns "/dashboard"
 * validateRedirectPath("//attacker.com") // returns "/dashboard"
 * validateRedirectPath(null) // returns "/dashboard"
 * validateRedirectPath(undefined) // returns "/dashboard"
 * validateRedirectPath("") // returns "/dashboard"
 */
export const validateRedirectPath = (path: string | undefined): string => {
  // Ensure path is a string
  if (!path || typeof path !== "string") {
    return "/dashboard";
  }

  // Trim whitespace
  const trimmedPath = path.trim();

  // Reject empty strings
  if (trimmedPath.length === 0) {
    return "/dashboard";
  }

  // Ensure path starts with "/" to block absolute URLs
  if (!trimmedPath.startsWith("/")) {
    return "/dashboard";
  }

  // Ensure path doesn't contain double slashes (protocol prefix)
  if (trimmedPath.startsWith("//")) {
    return "/dashboard";
  }

  // Check if path is in whitelist
  if (ALLOWED_REDIRECT_PATHS.includes(trimmedPath as typeof ALLOWED_REDIRECT_PATHS[number])) {
    return trimmedPath;
  }

  // Default fallback for any path not in whitelist
  return "/dashboard";
};

/**
 * Type-safe redirect path type derived from allowed paths
 * Useful for type-checking redirect destinations in TypeScript
 */
export type AllowedRedirectPath = typeof ALLOWED_REDIRECT_PATHS[number];

/**
 * Check if a path is allowed for redirects
 * @param path - The path to check
 * @returns True if the path is in the allowed list
 */
export const isAllowedRedirectPath = (path: string): path is AllowedRedirectPath => {
  return ALLOWED_REDIRECT_PATHS.includes(path as AllowedRedirectPath);
};
