import { createApp } from '@backstage/frontend-defaults';
import { SignInPageBlueprint } from '@backstage/plugin-app-react';
import { SignInPage } from '@backstage/core-components';
import { googleAuthApiRef } from '@backstage/core-plugin-api';
import appPlugin from '@backstage/plugin-app';
import catalogPlugin from '@backstage/plugin-catalog/alpha';
import techdocsPlugin from '@backstage/plugin-techdocs/alpha';
import scaffolderPlugin from '@backstage/plugin-scaffolder/alpha';
import searchPlugin from '@backstage/plugin-search/alpha';
import userSettingsPlugin from '@backstage/plugin-user-settings/alpha';
import notificationsPlugin from '@backstage/plugin-notifications/alpha';
import { navModule } from './modules/nav';

export default createApp({
  features: [
    catalogPlugin,
    techdocsPlugin,
    scaffolderPlugin,
    searchPlugin,
    userSettingsPlugin,
    notificationsPlugin,
    navModule,
    appPlugin.withOverrides({
      extensions: [
        // Authentication Gate
        SignInPageBlueprint.make({
          params: {
            loader: async () => (props) => (
              <SignInPage
                {...props}
                title="OM Platform Portal"
                providers={[
                  {
                    id: 'google',
                    title: 'Google',
                    message: 'Sign in using Google',
                    apiRef: googleAuthApiRef,
                  },
                  'guest',
                ]}
              />
            ),
          },
        }),
      ],
    }),
  ],
});
