import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    testTimeout: 120000,
    hookTimeout: 120000,
    include: ['tests/**/*.test.ts'],
    fileParallelism: false,
    pool: 'forks',
  },
});
