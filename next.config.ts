import type { NextConfig } from "next";

const config: NextConfig = {
  serverExternalPackages: ["@electric-sql/pglite", "postgres"],
  experimental: { proxyClientMaxBodySize: "60mb" },
};

export default config;
