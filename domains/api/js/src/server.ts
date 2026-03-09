import { createApp } from "./app.js";

// Node + Python affected PR
const app = createApp();
const port = Number(process.env.PORT || 3000);

app.listen(port, () => {
  console.log(`api-js-service listening on http://localhost:${port}`);
});
