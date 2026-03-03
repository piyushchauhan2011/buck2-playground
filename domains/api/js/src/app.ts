import express from "express";
import { health } from "./util.js";

export function createApp() {
  const app = express();

  app.get("/health", (_req, res) => {
    res.json(health());
  });

  app.get("/", (_req, res) => {
    res.send("API JS service is running");
  });

  return app;
}
