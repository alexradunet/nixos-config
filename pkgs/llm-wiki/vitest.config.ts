import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "node",
    include: ["tests/**/*.test.ts"],
    restoreMocks: true,
    clearMocks: true,
    coverage: {
      provider: "v8",
      reporter: ["text", "lcov"],
      include: ["extension/**/*.ts"],
      thresholds: {
        lines: 93,
        functions: 89,
        branches: 73,
        statements: 89,
      },
    },
  },
});
