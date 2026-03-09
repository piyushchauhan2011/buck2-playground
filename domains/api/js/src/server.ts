import { createApp } from "./app.js";

// Node service entry point
const app = createApp();
const port = Number(process.env.PORT || 3000);

app.listen(port, () => {
  console.log(`api-js-service listening on http://localhost:${port}`);
  console.log(`Environment: ${process.env.NODE_ENV || "development"}`);
});
