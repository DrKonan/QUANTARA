import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  basePath: "/quantara",
  // Toutes les routes seront servies sous /quantara/*
  // Apache fait le reverse proxy : juniari.com/quantara → localhost:4240/quantara
};

export default nextConfig;
