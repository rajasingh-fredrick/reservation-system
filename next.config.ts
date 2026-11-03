import type { NextConfig } from "next";

const config: NextConfig = {
  serverExternalPackages: ["mysql2"],
  experimental: { proxyClientMaxBodySize: "60mb" },
};

export default config;
