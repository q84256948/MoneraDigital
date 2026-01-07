import { validateRedirectPath, isAllowedRedirectPath } from "./redirect-validator";

describe("redirect-validator", () => {
  describe("validateRedirectPath", () => {
    describe("✅ Valid internal paths", () => {
      it("should allow root path", () => {
        expect(validateRedirectPath("/")).toBe("/");
      });

      it("should allow dashboard home", () => {
        expect(validateRedirectPath("/dashboard")).toBe("/dashboard");
      });

      it("should allow dashboard/lending", () => {
        expect(validateRedirectPath("/dashboard/lending")).toBe("/dashboard/lending");
      });

      it("should allow dashboard/assets", () => {
        expect(validateRedirectPath("/dashboard/assets")).toBe("/dashboard/assets");
      });

      it("should allow dashboard/security", () => {
        expect(validateRedirectPath("/dashboard/security")).toBe("/dashboard/security");
      });

      it("should allow dashboard/addresses", () => {
        expect(validateRedirectPath("/dashboard/addresses")).toBe("/dashboard/addresses");
      });

      it("should allow dashboard/withdraw", () => {
        expect(validateRedirectPath("/dashboard/withdraw")).toBe("/dashboard/withdraw");
      });

      it("should allow dashboard/statements", () => {
        expect(validateRedirectPath("/dashboard/statements")).toBe("/dashboard/statements");
      });
    });

    describe("❌ Security: Absolute URL attacks", () => {
      it("should block HTTP URLs", () => {
        expect(validateRedirectPath("http://evil.com")).toBe("/dashboard");
      });

      it("should block HTTPS URLs", () => {
        expect(validateRedirectPath("https://evil.com/phishing")).toBe("/dashboard");
      });

      it("should block protocol-relative URLs", () => {
        expect(validateRedirectPath("//evil.com")).toBe("/dashboard");
      });

      it("should block URLs with subdomain", () => {
        expect(validateRedirectPath("https://attacker.evil.com")).toBe("/dashboard");
      });

      it("should block URLs with query strings", () => {
        expect(validateRedirectPath("https://evil.com?callback=true")).toBe("/dashboard");
      });

      it("should block URLs with fragments", () => {
        expect(validateRedirectPath("https://evil.com#section")).toBe("/dashboard");
      });

      it("should block URLs with credentials", () => {
        expect(validateRedirectPath("https://user:pass@evil.com")).toBe("/dashboard");
      });

      it("should block URLs with port", () => {
        expect(validateRedirectPath("https://evil.com:8080")).toBe("/dashboard");
      });
    });

    describe("❌ Security: JavaScript execution attacks", () => {
      it("should block javascript: URIs", () => {
        expect(validateRedirectPath("javascript:alert(1)")).toBe("/dashboard");
      });

      it("should block data: URIs", () => {
        expect(validateRedirectPath("data:text/html,<script>alert(1)</script>")).toBe("/dashboard");
      });

      it("should block vbscript: URIs", () => {
        expect(validateRedirectPath("vbscript:msgbox(1)")).toBe("/dashboard");
      });

      it("should block file: URIs", () => {
        expect(validateRedirectPath("file:///etc/passwd")).toBe("/dashboard");
      });
    });

    describe("❌ Security: Path traversal attacks", () => {
      it("should block parent directory traversal", () => {
        expect(validateRedirectPath("/../../../etc/passwd")).toBe("/dashboard");
      });

      it("should block encoded parent directory traversal", () => {
        expect(validateRedirectPath("/%2e%2e/%2e%2e/%2e%2e/etc/passwd")).toBe("/dashboard");
      });

      it("should block path traversal to external site", () => {
        expect(validateRedirectPath("/dashboard/../../evil.com")).toBe("/dashboard");
      });

      it("should block backslash traversal", () => {
        expect(validateRedirectPath("\\..\\..\\evil.com")).toBe("/dashboard");
      });

      it("should block double URL encoding", () => {
        expect(validateRedirectPath("/%252e%252e/evil.com")).toBe("/dashboard");
      });

      it("should block null byte injection", () => {
        expect(validateRedirectPath("/dashboard%00.evil.com")).toBe("/dashboard");
      });
    });

    describe("❌ Security: Null/undefined handling", () => {
      it("should handle null input", () => {
        expect(validateRedirectPath(null as any)).toBe("/dashboard");
      });

      it("should handle undefined input", () => {
        expect(validateRedirectPath(undefined)).toBe("/dashboard");
      });

      it("should handle empty string", () => {
        expect(validateRedirectPath("")).toBe("/dashboard");
      });

      it("should handle whitespace only", () => {
        expect(validateRedirectPath("   ")).toBe("/dashboard");
      });

      it("should handle tabs and newlines", () => {
        expect(validateRedirectPath("\t\n")).toBe("/dashboard");
      });
    });

    describe("❌ Security: Type confusion attacks", () => {
      it("should handle number type", () => {
        expect(validateRedirectPath(123 as any)).toBe("/dashboard");
      });

      it("should handle object type", () => {
        expect(validateRedirectPath({} as any)).toBe("/dashboard");
      });

      it("should handle array type", () => {
        expect(validateRedirectPath([] as any)).toBe("/dashboard");
      });

      it("should handle boolean type", () => {
        expect(validateRedirectPath(true as any)).toBe("/dashboard");
      });
    });

    describe("❌ Security: Case sensitivity bypass", () => {
      it("should block uppercase JavaScript protocol", () => {
        expect(validateRedirectPath("JAVASCRIPT:alert(1)")).toBe("/dashboard");
      });

      it("should block mixed case Protocol", () => {
        expect(validateRedirectPath("JaVaScRiPt:alert(1)")).toBe("/dashboard");
      });

      it("should block uppercase HTTPS", () => {
        expect(validateRedirectPath("HTTPS://evil.com")).toBe("/dashboard");
      });
    });

    describe("❌ Security: Whitespace/encoding bypasses", () => {
      it("should handle leading/trailing whitespace", () => {
        expect(validateRedirectPath("  /dashboard  ")).toBe("/dashboard");
      });

      it("should block paths with embedded nulls", () => {
        expect(validateRedirectPath("/dashboard\x00.evil")).toBe("/dashboard");
      });

      it("should block Unicode bypass attempts", () => {
        expect(validateRedirectPath("/\u0065vil")).toBe("/dashboard");
      });

      it("should block paths with Unicode slashes", () => {
        expect(validateRedirectPath("\\u002f\\u002fevil.com")).toBe("/dashboard");
      });
    });

    describe("❌ Security: Open redirect patterns from CVEs", () => {
      it("should block common open redirect pattern 1", () => {
        // Similar to CVE-2018-1000310
        expect(validateRedirectPath("https://www.google.com/search?q=site:attacker.com")).toBe("/dashboard");
      });

      it("should block common open redirect pattern 2", () => {
        // Similar to CVE-2019-9193
        expect(validateRedirectPath("/admin/account?redirect=https://evil.com")).toBe("/dashboard");
      });

      it("should block localhost bypass", () => {
        expect(validateRedirectPath("http://localhost@evil.com")).toBe("/dashboard");
      });

      it("should block IP address redirect", () => {
        expect(validateRedirectPath("http://192.168.1.1")).toBe("/dashboard");
      });
    });

    describe("✅ Whitespace handling", () => {
      it("should trim whitespace from valid paths", () => {
        expect(validateRedirectPath("  /dashboard  ")).toBe("/dashboard");
      });

      it("should trim and validate", () => {
        expect(validateRedirectPath("  /dashboard/lending  ")).toBe("/dashboard/lending");
      });
    });

    describe("⚠️ Edge cases", () => {
      it("should handle very long strings", () => {
        const longString = "a".repeat(10000);
        expect(validateRedirectPath(longString)).toBe("/dashboard");
      });

      it("should handle paths with query strings", () => {
        expect(validateRedirectPath("/dashboard?param=value")).toBe("/dashboard");
      });

      it("should handle paths with fragments", () => {
        expect(validateRedirectPath("/dashboard#section")).toBe("/dashboard");
      });

      it("should block paths not in whitelist", () => {
        expect(validateRedirectPath("/admin")).toBe("/dashboard");
        expect(validateRedirectPath("/settings")).toBe("/dashboard");
        expect(validateRedirectPath("/profile")).toBe("/dashboard");
      });
    });
  });

  describe("isAllowedRedirectPath", () => {
    it("should return true for allowed paths", () => {
      expect(isAllowedRedirectPath("/dashboard")).toBe(true);
      expect(isAllowedRedirectPath("/dashboard/lending")).toBe(true);
      expect(isAllowedRedirectPath("/")).toBe(true);
    });

    it("should return false for disallowed paths", () => {
      expect(isAllowedRedirectPath("https://evil.com")).toBe(false);
      expect(isAllowedRedirectPath("/admin")).toBe(false);
      expect(isAllowedRedirectPath("")).toBe(false);
    });

    it("should have proper type guard behavior", () => {
      const testPath: string = "/dashboard";
      if (isAllowedRedirectPath(testPath)) {
        // TypeScript should recognize this as AllowedRedirectPath type
        const _validPath: typeof testPath = testPath;
        expect(_validPath).toBe("/dashboard");
      }
    });
  });

  describe("Performance", () => {
    it("should validate paths quickly", () => {
      const start = performance.now();
      for (let i = 0; i < 10000; i++) {
        validateRedirectPath("/dashboard/lending");
      }
      const end = performance.now();
      // Should complete 10k validations in less than 100ms
      expect(end - start).toBeLessThan(100);
    });

    it("should handle burst of invalid inputs efficiently", () => {
      const start = performance.now();
      for (let i = 0; i < 10000; i++) {
        validateRedirectPath("https://evil.com");
      }
      const end = performance.now();
      expect(end - start).toBeLessThan(100);
    });
  });
});
