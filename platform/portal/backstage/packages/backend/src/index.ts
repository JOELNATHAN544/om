/*
 * Hi!
 *
 * Note that this is an EXAMPLE Backstage backend. Please check the README.
 *
 * Happy hacking!
 */

import { createBackend } from '@backstage/backend-defaults';
import { createBackendModule } from '@backstage/backend-plugin-api';
import { authProvidersExtensionPoint, createOAuthProviderFactory } from '@backstage/plugin-auth-node';
import { googleAuthenticator } from '@backstage/plugin-auth-backend-module-google-provider';

const backend = createBackend();
const enablePgSearch =
  process.env.BACKSTAGE_USE_PG_SEARCH === 'true' ||
  process.env.NODE_ENV === 'production';

backend.add(import('@backstage/plugin-app-backend'));
backend.add(import('@backstage/plugin-proxy-backend'));

// scaffolder plugin
backend.add(import('@backstage/plugin-scaffolder-backend'));
backend.add(import('@backstage/plugin-scaffolder-backend-module-github'));
backend.add(
  import('@backstage/plugin-scaffolder-backend-module-notifications'),
);

// techdocs plugin
backend.add(import('@backstage/plugin-techdocs-backend'));

// auth plugin
backend.add(import('@backstage/plugin-auth-backend'));
// We use a custom module below to configure the Google provider with our resolver
backend.add(
  createBackendModule({
    pluginId: 'auth',
    moduleId: 'google-auth-config',
    register(reg) {
      reg.registerInit({
        deps: { providers: authProvidersExtensionPoint },
        async init({ providers }) {
          providers.registerProvider({
            providerId: 'google',
            factory: createOAuthProviderFactory({
              authenticator: googleAuthenticator,
              async signInResolver(info, ctx) {
                const { profile: { email } } = info;
                if (!email) throw new Error('Login failed: No email profile found');
                
                const [userId] = email.split('@');
                return ctx.issueToken({
                  claims: {
                    sub: `user:default/${userId}`,
                    ent: [
                      `user:default/${userId}`,
                      `group:default/platform-team`
                    ],
                  },
                });
              },
            }),
          });
        },
      });
    },
  })
);

// catalog plugin
backend.add(import('@backstage/plugin-catalog-backend'));
backend.add(
  import('@backstage/plugin-catalog-backend-module-scaffolder-entity-model'),
);
backend.add(import('@backstage/plugin-catalog-backend-module-github'));

// See https://backstage.io/docs/features/software-catalog/configuration#subscribing-to-catalog-errors
backend.add(import('@backstage/plugin-catalog-backend-module-logs'));

// permission plugin
backend.add(import('@backstage/plugin-permission-backend'));
// See https://backstage.io/docs/permissions/getting-started for how to create your own permission policy
backend.add(
  import('@backstage/plugin-permission-backend-module-allow-all-policy'),
);

// search plugin
if (enablePgSearch) {
  backend.add(import('@backstage/plugin-search-backend'));

  // search engine
  // See https://backstage.io/docs/features/search/search-engines
  backend.add(import('@backstage/plugin-search-backend-module-pg'));

  // search collators
  backend.add(import('@backstage/plugin-search-backend-module-catalog'));
  backend.add(import('@backstage/plugin-search-backend-module-techdocs'));
}

// kubernetes plugin
backend.add(import('@backstage/plugin-kubernetes-backend'));

// argocd plugin
backend.add(import('@backstage-community/plugin-argocd-backend'));

// notifications and signals plugins
backend.add(import('@backstage/plugin-notifications-backend'));
backend.add(import('@backstage/plugin-signals-backend'));

// mcp actions plugin
backend.add(import('@backstage/plugin-mcp-actions-backend'));

backend.start();
