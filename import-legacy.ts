import { cp, mkdir, stat } from "node:fs/promises";
import path from "node:path";
import { randomUUID } from "node:crypto";
import nextEnv from "@next/env";
import { PGlite } from "@electric-sql/pglite";
import { createMysqlPool, initializeMysql, mysqlOptions } from "../src/server/mysql.ts";
import { importLegacyRecords, LEGACY_TABLES, type LegacyTable } from "../src/server/legacy-import.ts";

nextEnv.loadEnvConfig(process.cwd());

async function main() {
  const args = process.argv.slice(2);
  const sourceIndex = args.indexOf("--source");
  if (sourceIndex < 0 || !args[sourceIndex + 1] || args[sourceIndex + 1].startsWith("--")) {
    throw new Error("Provide --source with the preserved PGlite directory. Add --apply only after a successful rehearsal.");
  }
  const recognized = new Set([sourceIndex, sourceIndex + 1, ...args.flatMap((arg, index) => arg === "--apply" ? [index] : [])]);
  if (args.some((_, index) => !recognized.has(index))) throw new Error("Unrecognized import argument.");
  const apply = args.includes("--apply");
  const source = path.resolve(args[sourceIndex + 1]);
  if (!(await stat(path.join(source, "PG_VERSION"))).isFile()) throw new Error("Source is not a PostgreSQL/PGlite database directory.");
  const snapshot = path.resolve(".data", `legacy-import-${Date.now()}-${randomUUID()}`);
  if (snapshot === source || snapshot.startsWith(source + path.sep)) throw new Error("Snapshot must not be inside the source database.");
  await mkdir(path.dirname(snapshot), { recursive: true });
  await cp(source, snapshot, { recursive: true, errorOnExist: true, force: false });
  console.info(`Preserved source copy: ${snapshot}`);
  const legacy = new PGlite(snapshot);
  const pool = createMysqlPool();
  try {
    const sourceTables = await legacy.query<{ table_name: string }>(
      "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'",
    );
    const unknown = sourceTables.rows.filter(({ table_name }) => table_name !== "schema_migrations" && !LEGACY_TABLES.some((name) => name === table_name));
    if (unknown.length) throw new Error("Source contains unmapped tables; import stopped to avoid silently omitting data.");
    const tables: LegacyTable[] = [];
    for (const name of LEGACY_TABLES) {
      if (!sourceTables.rows.some(({ table_name }) => table_name === name)) throw new Error(`Source is missing expected table ${name}.`);
      const columns = await legacy.query<{ column_name: string; data_type: string }>(
        "SELECT column_name,data_type FROM information_schema.columns WHERE table_schema='public' AND table_name=$1 ORDER BY ordinal_position", [name],
      );
      const projection = columns.rows.map(({ column_name, data_type }) => {
        if (!/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(column_name)) throw new Error("Unsupported source column.");
        return data_type === "date" ? `"${column_name}"::text AS "${column_name}"` : `"${column_name}"`;
      }).join(",");
      const rows = await legacy.query<Record<string, unknown>>(`SELECT ${projection} FROM "${name}"`);
      tables.push({ name, columns: columns.rows.map((column) => column.column_name), rows: rows.rows });
    }
    const uploads = path.resolve(process.env.UPLOAD_DIR || path.join(process.env.DATA_DIR || ".data", "uploads"));
    for (const row of tables.find((table) => table.name === "sheet_versions")!.rows) {
      const file = path.resolve(uploads, String(row.storage_key));
      if (!file.startsWith(uploads + path.sep)) throw new Error("Sheet storage key is outside the upload directory.");
      const info = await stat(file);
      if (!info.isFile() || info.size !== Number(row.size_bytes)) throw new Error("An uploaded sheet is missing or has an unexpected size.");
    }
    console.info("All referenced uploaded sheets exist and match their stored sizes.");
    await initializeMysql(pool);
    const connection = await pool.getConnection();
    try {
      await connection.beginTransaction();
      try {
        const report = await importLegacyRecords(connection, tables);
        console.table(report);
        if (apply) {
          await connection.commit();
          console.info("Import committed. Verifying persisted records in a new transaction...");
          await connection.beginTransaction();
          const verified = await importLegacyRecords(connection, tables);
          if (verified.some((table) => table.inserted !== 0)) throw new Error("Post-commit verification detected missing records.");
          await connection.rollback();
          console.info(`Verified ${verified.reduce((sum, table) => sum + table.source, 0)} source records across ${verified.length} tables in MySQL.`);
        } else {
          await connection.rollback();
          console.info("Rehearsal passed: all inserted values verified, then rolled back. MySQL application records are unchanged.");
        }
      } catch (error) {
        await connection.rollback();
        throw error;
      }
    } finally { connection.release(); }
    const options = mysqlOptions();
    console.info(`Destination: ${options.host}:${options.port}/${options.database}. MySQL migration history was not replaced.`);
  } finally {
    try { await legacy.close(); } finally { await pool.end(); }
  }
}

main().catch((error: unknown) => {
  const code = error && typeof error === "object" && "code" in error ? String(error.code) : undefined;
  // Driver messages may contain values from sensitive records; report only safe diagnostics.
  console.error(code ? `Legacy import failed (${code}); no conflicting record was overwritten.` : `Legacy import failed: ${error instanceof Error ? error.message : "unknown error"}`);
  process.exitCode = 1;
});
