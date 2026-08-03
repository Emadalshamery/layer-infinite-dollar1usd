# features/ai/github-app

This feature provides a starting skeleton for a GitHub App / webhook handler to integrate AI features into this repository.

Quick start

1. Copy `.env.example` to `.env` and fill the variables.
2. Install dependencies: `npm install`
3. Run in development: `npm run dev`
4. Build: `npm run build`
5. Run tests: `npm test`

What this includes

- Minimal Express-based webhook receiver (src/index.ts)
- TypeScript config and build scripts
- Basic CI workflow (GitHub Actions) to run tests

Notes

This is a scaffold. Implement actual AI integration / auth with GitHub App (private key, app id) as needed.
