import { defineConfig } from 'astro/config';
import starlight from '@astrojs/starlight';

export default defineConfig({
  integrations: [
    starlight({
      title: 'BlastShield',
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
