const express = require("express");
const os = require("os");

const app = express();

const PORT = process.env.PORT || 8080;
const APP_NAME = process.env.APP_NAME || "demo-app";
const VERSION = process.env.VERSION || "dev";

app.get("/", (req, res) => {
  res.json({
    app: APP_NAME,
    version: VERSION,
    pod: os.hostname(),
  });
});

app.get("/healthz", (req, res) => {
  res.status(200).json({
    status: "healthy",
  });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log(`Server listening on port ${PORT}`);
});