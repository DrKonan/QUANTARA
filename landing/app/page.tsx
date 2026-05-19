import Navbar from "@/components/Navbar";
import Hero from "@/components/Hero";
import Features from "@/components/Features";
import Screenshots from "@/components/Screenshots";
import Stats from "@/components/Stats";
import Pricing from "@/components/Pricing";
import Testimonials from "@/components/Testimonials";
import FAQ from "@/components/FAQ";
import Footer from "@/components/Footer";

export default function Home() {
  return (
    <main style={{ background: "#080810", minHeight: "100vh" }}>
      <Navbar />
      <Hero />
      <Stats />
      <Features />
      <Screenshots />
      <Pricing />
      <Testimonials />
      <FAQ />
      <Footer />
    </main>
  );
}
