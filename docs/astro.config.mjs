import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://cdrxyz.github.io',
  base: process.env.ASTRO_BASE || '/blastshield',
  integrations: [
    starlight({
      title: 'BlastShield',
      logo: {
        light: './src/assets/half-cedar-mark-light.svg',
        dark: './src/assets/half-cedar-mark-dark.svg',
      },
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/cdrxyz/blastshield' },
      ],
      components: {
        Banner: './src/components/BetaBanner.astro',
        Footer: './src/components/Footer.astro',
      },
      editLink: {
        baseUrl: 'https://github.com/cdrxyz/blastshield/edit/master/docs/src/content/docs/',
      },
      defaultLocale: 'root',
      locales: {
        root: {
          label: 'English',
          lang: 'en',
        },
      },
      sidebar: [
        { label: 'Getting Started', link: '/getting-started/' },
        { label: 'Architecture', link: '/architecture/' },
        { label: 'Profiles', link: '/profiles/' },
        { label: 'Guard', link: '/guard/' },
        { label: 'Layering', link: '/layering/' },
        { label: 'Whitepaper', link: '/whitepaper/' },
        { label: 'FAQ', link: '/faq/' },
      ],
    }),
  ],
});
