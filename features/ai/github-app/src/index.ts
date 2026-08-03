export {};

import express from "express";
import bodyParser from "body-parser";

const app = express();
const port = process.env.PORT || 3000;

app.use(bodyParser.json());

// Health check
app.get("/", (_req, res) => res.send("OK"));

// Webhook receiver (skeleton)
app.post("/api/webhook", (req, res) => {
  // TODO: verify signature using WEBHOOK_SECRET
  console.log("Received webhook:", req.headers["x-github-event"], req.body);

  // Example: handle issue_comment or pull_request events and call AI services
  // Implement signature verification and Octokit/GitHub App auth before making API calls.

  res.status(200).json({ received: true });
});

if (require.main === module) {
  app.listen(port, () => {
    console.log(`GitHub App skeleton listening on port ${port}`);
  });
}

export default app;
