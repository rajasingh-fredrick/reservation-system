import nextEnv from "@next/env";
import { createHash } from "node:crypto";
import { setTimeout } from "node:timers/promises";
import { createMysqlPool, mysqlOptions } from "../src/server/mysql.ts";
import { closeDatabase } from "../src/server/db.ts";
import { processImmediateNotifications } from "../src/server/email-queue.ts";

async function main() {
  if (process.argv.includes("--help")) {
    console.info("Run: npm run notifications:work [-- --once]");
    console.info("Polls immediate email queues every second. Set NODE_ENV=production for SMTP.");
    return;
  }
  nextEnv.loadEnvConfig(process.cwd(), process.env.NODE_ENV !== "production");
  if (process.env.NODE_ENV === "production" && (!process.env.SMTP_HOST || !process.env.SMTP_FROM)) {
    throw new Error("SMTP_HOST and SMTP_FROM must be configured.");
  }
  const options = mysqlOptions();
  const pool = createMysqlPool({ ...options, connectionLimit: 1 });
  let connection: Awaited<ReturnType<typeof pool.getConnection>> | undefined;
  const lock = `harmony:immediate:${createHash("sha256").update(String(options.database)).digest("hex").slice(0, 40)}`;
  let acquired = false;
  const stop = new AbortController();
  const shutdown = () => stop.abort();
  process.once("SIGINT", shutdown);
  process.once("SIGTERM", shutdown);
  try {
    connection = await pool.getConnection();
    const [rows] = await connection.query<import("mysql2").RowDataPacket[]>("SELECT GET_LOCK(?,0) AS acquired", [lock]);
    acquired = rows[0].acquired === 1;
    if (!acquired) {
      console.info("Immediate notification worker skipped: another worker holds the database lock.");
      return;
    }
    console.info("Immediate notification worker ready.");
    do {
      await connection.query("SELECT 1");
      const totals = await processImmediateNotifications();
      if (Object.values(totals).some(Boolean)) console.info("Immediate notification batch completed", totals);
      if (process.argv.includes("--once")) {
        if (totals.Failed || totals.Sending) process.exitCode = 1;
        break;
      }
      if (!stop.signal.aborted) {
        try { await setTimeout(1000, undefined, { signal: stop.signal }); }
        catch (error) {
          if (!(error instanceof Error && error.name === "AbortError")) throw error;
        }
      }
    } while (!stop.signal.aborted);
  } finally {
    process.removeListener("SIGINT", shutdown);
    process.removeListener("SIGTERM", shutdown);
    try {
      if (acquired && connection) await connection.query("SELECT RELEASE_LOCK(?)", [lock]);
    } finally {
      connection?.release();
      try { await pool.end(); } finally { await closeDatabase(); }
    }
  }
}

await main().catch((error: unknown) => {
  console.error("Immediate notification worker stopped. Check database, migrations, and SMTP configuration.",
    { code: error && typeof error === "object" && "code" in error ? String(error.code) : "WORKER_ERROR" });
  process.exitCode = 1;
});
