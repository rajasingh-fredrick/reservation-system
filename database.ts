import nextEnv from "@next/env";
import { createMysqlPool, initializeMysql, mysqlOptions } from "../src/server/mysql.ts";

nextEnv.loadEnvConfig(process.cwd());
const options = mysqlOptions();
const check = process.argv.includes("--check");
try {
  if (!check) {
    const admin = createMysqlPool({ ...options, database: undefined, connectionLimit: 1 });
    try {
      await admin.query(`CREATE DATABASE IF NOT EXISTS \`${options.database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_as_ci`);
    } finally {
      await admin.end();
    }
  }
  const pool = createMysqlPool(options);
  try {
    if (!check) await initializeMysql(pool);
    const [tables] = await pool.query("SHOW TABLES");
    const [version] = await pool.query("SELECT VERSION() AS version");
    const [migrations] = await pool.query("SELECT name,applied_at FROM schema_migrations ORDER BY name");
    console.info(`MySQL ${options.host}:${options.port}/${options.database}`);
    console.table(version);
    console.table(tables);
    console.table(migrations);
  } finally {
    await pool.end();
  }
} catch (error) {
  console.error("MySQL setup/check failed:", error instanceof Error ? error.message : "unknown error");
  process.exitCode = 1;
}
