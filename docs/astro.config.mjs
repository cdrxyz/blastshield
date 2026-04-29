import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  site: 'https://cdrxyz.github.io',
  base: '/blastshield',
  integrations: [
    starlight({
      title: 'BlastShield',
      social: [
        { icon: 'github', label: 'GitHub', href: 'https://github.com/cdrxyz/blastshield' },
      ],
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
        { label: 'FAQ', link: '/faq/' },
      ],
    }),
  ],
});
