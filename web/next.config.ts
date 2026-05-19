import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  basePath: "/nakora",
  // Toutes les routes seront servies sous /nakora/*
  // Apache fait le reverse proxy : juniari.com/nakora → localhost:4240/nakora
};

export default nextConfig;
