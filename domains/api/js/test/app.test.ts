import request from "supertest";
import { describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";

describe("api-js-service", () => {
  it("serves version endpoint", async () => {
    const app = createApp();
    const response = await request(app).get("/version");

    expect(response.status).toBe(200);
    expect(response.body.version).toBe("1.0.1");
  });

  it("serves root endpoint", async () => {
    const app = createApp();
    const response = await request(app).get("/");

    expect(response.status).toBe(200);
    expect(response.text).toContain("API JS service is running");
  });

  it("responds to ping", async () => {
    const app = createApp();
    const response = await request(app).get("/ping");

    expect(response.status).toBe(200);
    expect(response.body.pong).toBe(true);
  });

  it("serves health endpoint", async () => {
    const app = createApp();
    const response = await request(app).get("/health");

    expect(response.status).toBe(200);
    expect(response.body.ok).toBe(true);
    expect(response.body.service).toBe("api-js-service");
  });
});
