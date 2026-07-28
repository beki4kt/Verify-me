import express from "express";
import cors from "cors";
import { verifyRouter } from "./routes/verifyRoute";

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: "10mb" }));
app.use("/api", verifyRouter);

app.get("/health", (_req, res) => {
  res.json({ status: "ok", timestamp: new Date().toISOString() });
});

app.listen(PORT, "0.0.0.0", () => {
  console.log("Verify-me API running on http://0.0.0.0:" + PORT);
});

export default app;
