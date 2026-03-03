import request from "supertest";
import { describe, expect, it } from "vitest";
import { createApp } from "../src/app.js";

describe("api-js-service", () => {
  it("serves root endpoint", async () => {
    const app = createApp();
    const response = await request(app).get("/");

    expect(response.status).toBe(200);
    expect(response.text).toContain("API JS service is running");
  });

  it("serves health endpoint", async () => {
    const app = createApp();
    const response = await request(app).get("/health");

    expect(response.status).toBe(200);
    expect(response.body.ok).toBe(true);
    expect(response.body.service).toBe("api-js-service");
  });
});
