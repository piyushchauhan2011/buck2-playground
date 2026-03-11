import express from "express";
import { health } from "./util.js";

export function createApp(): ReturnType<typeof express> {
  const app = express();

  app.get("/version", (_req, res) => {
    res.json({ version: "1.0.1" });
  });

  app.get("/health", (_req, res) => {
    res.json(health());
  });

  app.get("/ping", (_req, res) => {
    res.json({ pong: true });
  });

  app.get("/", (_req, res) => {
    res.send("API JS service is running");
  });

  return app;
}
