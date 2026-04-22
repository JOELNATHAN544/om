import { createApp } from '@backstage/frontend-defaults';
import catalogPlugin from '@backstage/plugin-catalog/alpha';
import kubernetesPlugin from '@backstage/plugin-kubernetes/alpha';
import techdocsPlugin from '@backstage/plugin-techdocs/alpha';
import scaffolderPlugin from '@backstage/plugin-scaffolder/alpha';
import searchPlugin from '@backstage/plugin-search/alpha';
import userSettingsPlugin from '@backstage/plugin-user-settings/alpha';
import notificationsPlugin from '@backstage/plugin-notifications/alpha';
import signalsPlugin from '@backstage/plugin-signals/alpha';
import { navModule } from './modules/nav';

export default createApp({
  features: [
    catalogPlugin,
    kubernetesPlugin,
    techdocsPlugin,
    scaffolderPlugin,
    searchPlugin,
    userSettingsPlugin,
    notificationsPlugin,
    signalsPlugin,
    navModule,
  ],
});
