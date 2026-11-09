import nextEnv from "@next/env";
import { createHash } from "node:crypto";
import { createMysqlPool, mysqlOptions } from "../src/server/mysql.ts";
import { closeDatabase } from "../src/server/db.ts";
import { runNotificationJob } from "../src/server/automated-notifications.ts";

async function main() {
  if (process.argv.includes("--help")) {
    console.info("Run from the project directory: npm run notifications:send");
    console.info("Schedule hourly. Set NODE_ENV=production for SMTP; development logs Preview emails only.");
    return;
  }
  // Unlike next dev, a scheduled job must explicitly select production for real SMTP.
  nextEnv.loadEnvConfig(process.cwd(), process.env.NODE_ENV !== "production");
  const options = mysqlOptions();
  const pool = createMysqlPool({ ...options, connectionLimit: 1 });
  let connection: Awaited<ReturnType<typeof pool.getConnection>> | undefined;
  const lock = `harmony:email:${createHash("sha256").update(String(options.database)).digest("hex").slice(0, 40)}`;
  let acquired = false;
  try {
    connection = await pool.getConnection();
    const [rows] = await connection.query<import("mysql2").RowDataPacket[]>("SELECT GET_LOCK(?,0) AS acquired", [lock]);
    acquired = rows[0].acquired === 1;
    if (!acquired) {
      console.info("Notification job skipped: another run holds the database lock.");
    } else {
      const totals = await runNotificationJob();
      console.info("Notification job completed", totals);
      if (totals.Failed || totals.Sending) process.exitCode = 1;
    }
  } finally {
    try {
      if (acquired && connection) await connection.query("SELECT RELEASE_LOCK(?)", [lock]);
    } finally {
      connection?.release();
      try { await pool.end(); } finally { await closeDatabase(); }
    }
  }

}

await main().catch((error: unknown) => {
  console.error("Notification job failed. Check database connectivity, migrations, APP_URL, recording instructions, and SMTP configuration.",
    { code: error && typeof error === "object" && "code" in error ? String(error.code) : "JOB_ERROR" });
  process.exitCode = 1;
});
