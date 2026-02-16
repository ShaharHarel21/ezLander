import Navbar from '@/components/Navbar'
import Pricing from '@/components/Pricing'
import FAQ from '@/components/FAQ'
import Footer from '@/components/Footer'

export const metadata = {
  title: 'Pricing - ezLander',
  description: 'Simple, transparent pricing for ezLander. Start with a 7-day free trial.',
}

export default function PricingPage() {
  return (
    <>
      <Navbar />
      <div className="pt-20">
        <Pricing />
        <FAQ />
      </div>
      <Footer />
    </>
  )
}
